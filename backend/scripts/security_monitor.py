import os
import ipaddress
import shutil
import re
import sys
import time
import urllib.request
import urllib.parse
import json
import collections
import subprocess
import sqlite3
import threading
import base64
import secrets
import queue
import html
import math
import ssl
import signal
from http.server import HTTPServer, BaseHTTPRequestHandler

# Handle thread concurrency for Dashboard HTTP server (Phase 3 Optimization)
try:
    from http.server import ThreadingHTTPServer
except ImportError:
    import socketserver
    class ThreadingHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
        daemon_threads = True

# Paths and Constants
CONFIG_PATH = '/etc/security-monitor.conf'
DEFAULT_LOG_PATH = '/var/log/nginx/access.log'
ALERT_LOG_PATH = '/var/log/security-alerts.log'
DB_PATH = '/var/log/security_monitor.db'

# Locks for configuration and thread-safety
config_lock = threading.Lock()
baseline_lock = threading.Lock()

# Whitelisted IPs to prevent accidental self-blocking
WHITELISTED_IPS = {
    '127.0.0.1', 
    '::1', 
    '152.239.113.87'  # Server's own public IP
}

# Configuration Settings & Defaults (can be customized via /etc/security-monitor.conf)
ENABLE_SQLI = True
ENABLE_XSS = True
ENABLE_RCE = True
ENABLE_TRAVERSAL = True
ENABLE_SCANNER = True
ENABLE_SSRF = True
ENABLE_XXE = True
ENABLE_REDIRECT = True
ENABLE_JWT = True
ENABLE_ANOMALY = True

SQLI_THRESHOLD = 70
XSS_THRESHOLD = 70
MAX_ATTEMPTS_PER_IP = 10
BLOCK_DURATION = 3600  # 1 hour
DASHBOARD_API_KEY = ""
DASHBOARD_BIND_IP = "127.0.0.1"  # Hardened default: bind to localhost
DASHBOARD_ALLOW_EXTERNAL = False  # Set to True to allow binding to 0.0.0.0
DASHBOARD_ALLOWED_IPS = set()      # Access Control List for dashboard admin

SSL_CERT_PATH = ""
SSL_KEY_PATH = ""

# ----------------- LRU Cache Implementation -----------------

class LRUCache:
    """Thread-safe Least Recently Used (LRU) Cache with optional TTL expiry.

    Each entry is stored as a tuple (value, inserted_at). If ttl is set (seconds),
    entries older than ttl are treated as expired and removed on access.
    """
    def __init__(self, maxsize=1000, ttl=None):
        self.cache = collections.OrderedDict()
        self.maxsize = maxsize
        self.ttl = ttl          # None = no expiry, float = seconds until stale
        self.lock = threading.Lock()

    def _is_expired(self, inserted_at):
        """Returns True if the entry has exceeded its TTL."""
        if self.ttl is None:
            return False
        return (time.time() - inserted_at) > self.ttl

    def get(self, key, default=None):
        with self.lock:
            if key not in self.cache:
                return default
            value, inserted_at = self.cache[key]
            if self._is_expired(inserted_at):
                del self.cache[key]
                return default
            self.cache.move_to_end(key)
            return value

    def set(self, key, value):
        with self.lock:
            now = time.time()
            if key in self.cache:
                self.cache.move_to_end(key)
            self.cache[key] = (value, now)
            if len(self.cache) > self.maxsize:
                self.cache.popitem(last=False)  # Evict oldest element

    def remove(self, key):
        with self.lock:
            if key in self.cache:
                del self.cache[key]

    def keys(self):
        with self.lock:
            now = time.time()
            if self.ttl is not None:
                return [k for k, (v, ts) in self.cache.items() if not self._is_expired(ts)]
            return list(self.cache.keys())

    def items(self):
        with self.lock:
            now = time.time()
            if self.ttl is not None:
                return [(k, v) for k, (v, ts) in self.cache.items() if not self._is_expired(ts)]
            return [(k, v) for k, (v, ts) in self.cache.items()]

    def clear(self):
        with self.lock:
            self.cache.clear()

# Global LRU Caches for memory protection
# blocked_ip_cache uses TTL matching BLOCK_DURATION to auto-expire cached ban decisions
geoip_cache = LRUCache(maxsize=1000)
attack_tracker = LRUCache(maxsize=1000)
client_history = LRUCache(maxsize=1000)
alert_buffer = LRUCache(maxsize=1000)
dashboard_rate_tracker = LRUCache(maxsize=1000)
dashboard_lockout_tracker = LRUCache(maxsize=1000)
successful_auth_ips = LRUCache(maxsize=100)  # Rate limit dashboard logs

# ----------------- Threat Detection Signatures -----------------

# Context-matching scoring rules for SQL Injection (SQLi)
SQLI_SCORING = [
    # High confidence keywords (70+ score = immediate detection)
    (re.compile(r'\bunion\s+(all\s+)?select\b', re.I), 80),
    (re.compile(r'\bselect\s+(?:[\w_]+(?:\s*,\s*[\w_]+)*|\*|0x[0-9a-fA-F]+|\d+)\s+from\b', re.I), 80),
    (re.compile(r'\bbenchmark\s*\(\s*\d+\s*,', re.I), 80),
    (re.compile(r'\bsleep\s*\(\s*\d+\s*\)', re.I), 80),
    (re.compile(r'\binformation_schema\b', re.I), 75),
    (re.compile(r'\bsysdatabases\b', re.I), 75),
    (re.compile(r'\bsysobjects\b', re.I), 75),
    (re.compile(r'\'\s*or\s*1\s*=\s*1', re.I), 75),
    (re.compile(r'"\s*or\s*1\s*=\s*1', re.I), 75),
    (re.compile(r'\bor\s+\d+=\d+', re.I), 70),
    (re.compile(r'\band\s+\d+=\d+', re.I), 70),
    # Medium confidence keywords (require multiple signals to trigger block)
    (re.compile(r'\bunion\b', re.I), 20),
    (re.compile(r'\bselect\b', re.I), 20),
    (re.compile(r'\binsert\b', re.I), 20),
    (re.compile(r'\bupdate\b', re.I), 20),
    (re.compile(r'\bdelete\b', re.I), 20),
    (re.compile(r'\bfrom\b', re.I), 10),
    (re.compile(r'--\s*$', re.I), 30),
    (re.compile(r'/\*', re.I), 30),
    (re.compile(r'\*/', re.I), 30),
    (re.compile(r'\bgroup_concat\b', re.I), 40),
    (re.compile(r'\bconcat\s*\(', re.I), 40),
    (re.compile(r'\bcoalesce\b', re.I), 30),
    (re.compile(r'\border\s+by\s+\d+\b', re.I), 50),
]

# Context-matching scoring rules for Cross-Site Scripting (XSS)
XSS_SCORING = [
    # High confidence keywords (70+ score)
    (re.compile(r'<\s*script[^>]*>', re.I), 80),
    (re.compile(r'<\s*/\s*script\s*>', re.I), 80),
    (re.compile(r'\bjavascript\s*:', re.I), 80),
    (re.compile(r'\bvbscript\s*:', re.I), 80),
    (re.compile(r'\bdata\s*:\s*text/html', re.I), 80),
    (re.compile(r'\bdocument\s*\.\s*(cookie|write)\b', re.I), 75),
    (re.compile(r'\bwindow\s*\.\s*(location|name|onload)\b', re.I), 75),
    # Medium confidence keywords
    (re.compile(r'\bon[a-z]+\s*=\s*["\']?[^"\'>]+["\']?', re.I), 45),  # event handlers (onload=, onerror=, etc.)
    (re.compile(r'\balert\s*\([^)]*\)', re.I), 45),
    (re.compile(r'\bprompt\s*\([^)]*\)', re.I), 45),
    (re.compile(r'\bconfirm\s*\([^)]*\)', re.I), 45),
    (re.compile(r'<\s*svg[^>]*>', re.I), 45),
    (re.compile(r'<\s*iframe[^>]*>', re.I), 45),
    (re.compile(r'<\s*embed[^>]*>', re.I), 45),
    (re.compile(r'<\s*object[^>]*>', re.I), 45),
    (re.compile(r'&#x', re.I), 30),
    (re.compile(r'\\u00', re.I), 30),
]

# Path Traversal and Local File Inclusion (LFI)
TRAVERSAL_PATTERN = re.compile(
    r'(\.\./|\.\.\\|/etc/(passwd|hosts|shadow|group)|/proc/self/|boot\.ini|win\.ini|windows/win\.ini|system32|/var/log/|php://(filter|input|temp)|phar://|gopher://)', 
    re.IGNORECASE
)

# Command Injection & Remote Code Execution (RCE)
RCE_PATTERN = re.compile(
    r'([;&|`]\s*(whoami|id|uname|hostname|ping|wget|curl|nc|netcat|powershell|ncat|bash|sh|cmd\.exe))|\b(eval|assert|passthru|shell_exec|system)\s*\(',
    re.IGNORECASE
)

# Scanner scan endpoint targets
SCANNER_PATTERN = re.compile(
    r'(\.env|\.git|\.svn|\.hg|\.htaccess|\.htpasswd|\.vscode|config\.php|database\.yml|settings\.py|web\.config|wp-admin|wp-login\.php|wp-content|xmlrpc\.php|phpmyadmin|pma/|setup\.php|info\.php|phpinfo\.php|laravel|actuator/health|actuator/env|v2/api-docs|swagger-ui|\.zip|\.tar|\.gz|\.bak|\.sql|shell\.php|cmd\.php|c99\.php|r57\.php|upload\.php|ws\.php)', 
    re.IGNORECASE
)

# Automated vulnerability scanners User Agents
SUSPICIOUS_UA_PATTERN = re.compile(
    r'(sqlmap|nmap|nikto|acunetix|dirbuster|gobuster|censys|shodan|masscan|w3af|hydra|nessus|zgrab|netsparker|openvas|nuclei|nimbostratus|arachni)',
    re.IGNORECASE
)

# Server-Side Request Forgery (SSRF)
SSRF_PATTERN = re.compile(
    r'(https?|gopher|ftp|file|dict)://(localhost|127\.0\.0\.1|10\.|192\.168\.|172\.(?:1[6-9]|2[0-9]|3[01])\.|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
    re.IGNORECASE
)

# XML External Entity (XXE)
XXE_PATTERN = re.compile(
    r'(<!ENTITY|<!DOCTYPE|SYSTEM|PUBLIC|file://)',
    re.IGNORECASE
)

# Open Redirect
REDIRECT_PATTERN = re.compile(
    r'[?&](url|redirect|next|goto|destination|target|link|ref|to)=https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    re.IGNORECASE
)

# JWT Abuse
JWT_ABUSE_PATTERN = re.compile(
    r'eyJhbGciOiJub25lIi',  # base64 representation of {"alg":"none"
    re.IGNORECASE
)

# Quick match keywords to optimize CPU overhead (Phase 3 Optimization)
QUICK_SQLI_KEYWORDS = ['select', 'union', 'insert', 'update', 'delete', 'from', '--', '/*', 'benchmark', 'sleep', 'information_schema']
QUICK_XSS_KEYWORDS = ['script', 'javascript', 'vbscript', 'alert', 'prompt', 'confirm', 'onload', 'onerror', 'onmouseover', 'svg', 'iframe', 'object', 'embed']
QUICK_RCE_KEYWORDS = [';', '|', '&', '`', 'whoami', 'id', 'uname', 'hostname', 'wget', 'curl', 'eval(', 'system(']
QUICK_TRAVERSAL_KEYWORDS = ['..', '/etc', 'passwd', 'hosts', 'shadow', 'group', 'win.ini', 'boot.ini', 'system32']
QUICK_SSRF_KEYWORDS = ['http://', 'https://', 'gopher://', 'ftp://', 'file://', 'dict://']
QUICK_XXE_KEYWORDS = ['<!entity', '<!doctype', 'system', 'public']
QUICK_REDIRECT_KEYWORDS = ['url=', 'redirect=', 'next=', 'goto=', 'destination=', 'target=', 'link=', 'to=']
QUICK_JWT_KEYWORDS = ['eyjhbGciOiJub25lIi', 'eyj']

# Remediation and security advice for alerts
REMEDIATION_ADVICE = {
    "SQL Injection (SQLi)": {
        "analysis": "تم اكتشاف محاولة حقن قواعد البيانات (SQLi) عبر استخدام كلمات مفتاحية مشبوهة مثل union/select/sleep/or 1=1 لمحاولة استخراج البيانات أو تجاوز المصادقة.",
        "remediation": "يُنصح باستخدام الاستعلامات المجهزة (Parameterized Queries / Prepared Statements) وتجنب دمج مدخلات المستخدم مباشرة في استعلامات SQL، بالإضافة إلى التحقق الصارم من نوع وحجم البيانات المدخلة."
    },
    "Cross-Site Scripting (XSS)": {
        "analysis": "تم رصد محاولة هجوم حقن النصوص البرمجية (XSS) عبر تضمين وسوم HTML أو أكواد جافا سكريبت مثل <script> أو onerror لمحاولة سرقة جلسات المستخدمين (Cookies) أو تغيير محتوى الصفحة.",
        "remediation": "يجب تنقية وترميز جميع المدخلات والمخرجات (HTML Entity Encoding) قبل عرضها في المتصفح، وتطبيق سياسة أمان المحتوى (Content Security Policy - CSP) للحد من تشغيل الأكواد البرمجية الخارجية."
    },
    "Path Traversal / LFI": {
        "analysis": "تم رصد محاولة قراءة ملفات النظام الداخلية أو تضمين ملفات محلية (LFI) عبر استخدام تسلسلات مسار مشبوهة مثل ../.. أو محاولة الوصول لملفات حساسة كملف /etc/passwd.",
        "remediation": "يجب تعطيل تضمين الملفات الديناميكي بناءً على مدخلات المستخدم، أو استخدام whitelist صارمة للملفات المسموح بطلبها، وتأمين صلاحيات القراءة لملفات النظام بحيث لا يمكن للويب سيرفر قراءتها."
    },
    "Remote Code Execution (RCE)": {
        "analysis": "تم اكتشاف محاولة تشغيل أوامر برمجية على السيرفر (RCE) عبر استغلال دوال التنفيذ أو محاولة إدخال رموز ربط الأوامر مثل ; أو && لتنفيذ أوامر كـ whoami أو curl.",
        "remediation": "يجب تجنب استخدام دوال تشغيل أوامر النظام (مثل eval, exec, system) كلياً، وتنقية المدخلات بشكل فائق الصرامة إذا كان استخدامها حتمياً، وضمان تشغيل التطبيق بأقل صلاحيات ممكنة (Principle of Least Privilege)."
    },
    "Vulnerability / Scanner Scan": {
        "analysis": "تم رصد نشاط مسح آلي للبحث عن ثغرات أو ملفات حساسة شائعة (مثل .env أو wp-admin أو ملفات النسخ الاحتياطي .zip) مما يشير إلى محاولة استطلاع ما قبل الهجوم.",
        "remediation": "تأكد من حظر الوصول للملفات الحساسة والمجلدات الإدارية على مستوى إعدادات Nginx، وتغيير مسارات لوحة التحكم الافتراضية، وإخفاء إصدارات الخدمات (server_tokens off) لتقليل المعلومات المتاحة للمهاجم."
    },
    "Directory Fuzzing / Brute-Force": {
        "analysis": "تم كشف محاولات فحص سريعة ومتكررة للمسارات غير الموجودة (فوزينج) بهدف تخمين وحصر المجلدات والملفات المخفية على السيرفر.",
        "remediation": "يفضل تفعيل حد الطلبات (Rate Limiting) على مستوى Nginx أو Cloudflare للحد من سرعة الفحص الآلي وحظر العناوين التي تسبب كثرة أخطاء 404 تلقائياً."
    },
    "Suspicious User-Agent / Scanner Bot": {
        "analysis": "تم رصد اتصال باستخدام برنامج مسح أو أداة آلية معروفة (مثل sqlmap أو nmap أو nikto) عبر تحليل حقل User-Agent.",
        "remediation": "يُنصح بحظر برامج الفحص الآلية المعروفة على مستوى Nginx باستخدام قواعد الـ User-Agent، أو استخدام خدمة حماية مثل Cloudflare لمنع أدوات الاستطلاع الآلي."
    },
    "Anomalous Traffic": {
        "analysis": "تم كشف نمط سلوك غير طبيعي للاتصال (مثل إغراق السيرفر بالطلبات العشوائية، أو إرسال معاملات ذات أحجام ضخمة جداً، أو التسبب في كمية كبيرة من أخطاء الاتصال 4xx/5xx).",
        "remediation": "يُنصح بمراجعة إعدادات Rate Limiting في Nginx وتفعيل جدار حماية لتصفية الطلبات غير الطبيعية تلقائياً قبل وصولها للتطبيق."
    },
    "SSRF": {
        "analysis": "تم رصد محاولة هجوم تزوير الطلبات من جانب الخادم (SSRF) بهدف جعل خادم الويب يقوم إرسال طلبات مشبوهة إلى عناوين داخلية أو خارجية غير مصرح بها.",
        "remediation": "يُنصح بعدم تمرير عناوين URL مباشرة من المستخدم، والتحقق الصارم من المدخلات باستخدام Whitelist للعناوين المسموح بها، وتعطيل استدعاء البروتوكولات غير المستخدمة."
    },
    "XXE": {
        "analysis": "تم كشف محاولة هجوم الكيانات الخارجية لـ XML (XXE) عبر محاولة حقن بنية XML تحتوي على كيانات خارجية للوصول لملفات النظام أو إحداث DoS.",
        "remediation": "يجب تعطيل معالجة الكيانات الخارجية (DED - External Entities) والمستندات الخارجية في جميع مكتبات معالجة XML المستخدمة في التطبيق."
    },
    "Open Redirect": {
        "analysis": "تم اكتشاف محاولة استغلال ميزة إعادة التوجيه المفتوح (Open Redirect) لتوجيه المستخدمين إلى روابط خارجية مشبوهة أو صفحات تصيد بعد تسجيل الدخول.",
        "remediation": "يجب تجنب إعادة التوجيه الديناميكي بناءً على معطيات المستخدم، أو التحقق الصارم من الوجهة بحيث تكون تابعة لنفس الدومين فقط."
    },
    "JWT Abuse": {
        "analysis": "تم كشف محاولة التلاعب بـ JWT (JSON Web Token) عبر تمرير خوارزمية التشفير alg:none لتجاوز التحقق من التوقيع.",
        "remediation": "تأكد من إعداد مكتبة التحقق من JWT لرفض خوارزمية 'none' صراحةً، ومطابقة التوقيع دائماً باستخدام المفتاح السري المعتمد."
    }
}

# ----------------- Global Control Structures -----------------

db_write_queue = queue.Queue()
shutdown_event = threading.Event()
httpd_server = None  # Initialized in run_dashboard_server(); referenced by shutdown handler

# Statistical anomaly detection baseline
normal_request_features = collections.deque(maxlen=300)
MIN_BASELINE_SAMPLES = 50

# ----------------- Database Core & Indexes -----------------

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("PRAGMA busy_timeout=5000;")
    except Exception as e:
        print(f"Error setting WAL/busy_timeout on connection: {e}")
    return conn

def execute_read(query, params=(), row_factory=None):
    conn = None
    try:
        conn = get_db_connection()
        if row_factory:
            conn.row_factory = row_factory
        c = conn.cursor()
        c.execute(query, params)
        return c.fetchall()
    except Exception as e:
        print(f"Database read error: {e}")
        return []
    finally:
        if conn:
            conn.close()

def execute_read_one(query, params=()):
    conn = None
    try:
        conn = get_db_connection()
        c = conn.cursor()
        c.execute(query, params)
        return c.fetchone()
    except Exception as e:
        print(f"Database read one error: {e}")
        return None
    finally:
        if conn:
            conn.close()

def queue_db_write(query, params=()):
    db_write_queue.put((query, params))

def _make_db_writer_connection():
    """Create and configure a fresh SQLite connection for the DB writer thread."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA busy_timeout=5000;")
    return conn

def db_writer_worker():
    """Background database writer with automatic reconnect on connection failure.

    Drains the write queue in batches of up to 50 items. If the connection dies
    (OperationalError / DatabaseError), it closes the broken socket and reopens a
    fresh connection so writes are never permanently lost while the service runs.
    """
    print("Database writer background thread started.")
    conn = None
    try:
        conn = _make_db_writer_connection()
    except Exception as e:
        print(f"[DB] Initial connection failed: {e}. Will retry on first write.")

    while True:
        tasks = []
        try:
            task = db_write_queue.get()
            if task is None:  # Sentinel value to exit
                break

            tasks = [task]
            while not db_write_queue.empty() and len(tasks) < 50:
                try:
                    next_task = db_write_queue.get_nowait()
                    if next_task is None:
                        db_write_queue.put(None)  # re-queue sentinel for self
                        break
                    tasks.append(next_task)
                except queue.Empty:
                    break

            # --- Health check: reconnect if connection is broken ---
            if conn is None:
                try:
                    conn = _make_db_writer_connection()
                    print("[DB] Reconnected to SQLite database.")
                except Exception as e:
                    print(f"[DB] Reconnect failed: {e}. Discarding batch of {len(tasks)} writes.")
                    for _ in tasks:
                        db_write_queue.task_done()
                    continue

            cursor = conn.cursor()
            for query, params in tasks:
                cursor.execute(query, params)
            conn.commit()

            for _ in tasks:
                db_write_queue.task_done()

        except (sqlite3.OperationalError, sqlite3.DatabaseError) as e:
            # Connection-level error — close and force reconnect next iteration
            print(f"[DB] Connection-level error, will reconnect: {e}")
            try:
                conn.close()
            except Exception:
                pass
            conn = None
            for _ in tasks:
                db_write_queue.task_done()

        except Exception as e:
            print(f"[DB] Writer thread unexpected error: {e}")
            try:
                conn.rollback()
            except Exception:
                pass
            for _ in tasks:
                db_write_queue.task_done()

    try:
        if conn:
            conn.close()
    except Exception:
        pass

def log_audit_action(action, target_ip, details, actor="system_daemon"):
    query = '''
        INSERT INTO audit_logs (timestamp, action, actor, ip, details)
        VALUES (?, ?, ?, ?, ?)
    '''
    params = (time.time(), action, actor, target_ip, details)
    queue_db_write(query, params)

def init_db():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Attacks table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS attacks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ip TEXT,
                timestamp REAL,
                threat_type TEXT,
                path TEXT,
                method TEXT,
                status_code TEXT,
                user_agent TEXT,
                country TEXT,
                city TEXT,
                isp TEXT
            )
        ''')
        
        # Blocked IPs table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS blocked_ips (
                ip TEXT PRIMARY KEY,
                blocked_at REAL,
                unban_at REAL,
                reason TEXT
            )
        ''')

        # Audit Logs table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS audit_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL,
                action TEXT,
                actor TEXT,
                ip TEXT,
                details TEXT
            )
        ''')

        # GeoIP Cache table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS geoip_cache (
                ip TEXT PRIMARY KEY,
                country TEXT,
                city TEXT,
                isp TEXT,
                cached_at REAL
            )
        ''')
        
        # Performance Indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_attacks_ip ON attacks(ip);")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_attacks_timestamp ON attacks(timestamp);")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_blocked_ips_unban_at ON blocked_ips(unban_at);")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);")
        
        conn.commit()
        print(f"SQLite database initialized at {DB_PATH}")
    except Exception as e:
        print(f"Error initializing SQLite database: {e}")
    finally:
        if conn:
            conn.close()

def log_attack_to_db(ip, threat_type, path, method, status_code, agent, geo):
    query = '''
        INSERT INTO attacks (ip, timestamp, threat_type, path, method, status_code, user_agent, country, city, isp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    '''
    params = (ip, time.time(), threat_type, path, method, status_code, agent, geo['country'], geo['city'], geo['isp'])
    queue_db_write(query, params)

def add_blocked_ip_to_db(ip, duration, reason, actor="system_daemon"):
    now = time.time()
    unban_at = now + duration
    query = '''
        INSERT OR REPLACE INTO blocked_ips (ip, blocked_at, unban_at, reason)
        VALUES (?, ?, ?, ?)
    '''
    params = (ip, now, unban_at, reason)
    queue_db_write(query, params)
    log_audit_action("BLOCK_IP", ip, f"IP blocked for {duration}s. Reason: {reason}", actor=actor)

def remove_blocked_ip_from_db(ip, actor="system_daemon"):
    query = 'DELETE FROM blocked_ips WHERE ip = ?'
    queue_db_write(query, (ip,))
    log_audit_action("UNBLOCK_IP", ip, "IP unbanned", actor=actor)

# ----------------- Decoders & Parsers -----------------

def recursive_url_decode(s, depth=3):
    last = s
    for _ in range(depth):
        try:
            decoded = urllib.parse.unquote_plus(last)
            if decoded == last:
                break
            last = decoded
        except Exception:
            break
    return last

BASE64_REGEX = re.compile(r'^[A-Za-z0-9+/]+={0,2}$')

def attempt_base64_decode(s):
    s_clean = s.strip()
    if len(s_clean) < 8 or not BASE64_REGEX.match(s_clean):
        return s
    try:
        decoded_bytes = base64.b64decode(s_clean + "===")
        decoded_str = decoded_bytes.decode('utf-8', errors='ignore')
        if any(c.isalnum() for c in decoded_str):
            return decoded_str
    except Exception:
        pass
    return s

def attempt_base64_decode_url(url_path):
    try:
        segments = re.split(r'[?&=]', url_path)
        decoded_segments = []
        for s in segments:
            decoded_s = attempt_base64_decode(s)
            if decoded_s != s:
                decoded_segments.append(decoded_s)
        if decoded_segments:
            return url_path + " " + " ".join(decoded_segments)
    except Exception:
        pass
    return url_path

# ----------------- Configuration Management -----------------

def load_config():
    global BLOCK_DURATION, MAX_ATTEMPTS_PER_IP, DASHBOARD_API_KEY, DASHBOARD_BIND_IP, DASHBOARD_ALLOW_EXTERNAL, DASHBOARD_ALLOWED_IPS
    global SSL_CERT_PATH, SSL_KEY_PATH
    global ENABLE_SQLI, ENABLE_XSS, ENABLE_RCE, ENABLE_TRAVERSAL, ENABLE_SCANNER, ENABLE_SSRF, ENABLE_XXE, ENABLE_REDIRECT, ENABLE_JWT, ENABLE_ANOMALY
    global SQLI_THRESHOLD, XSS_THRESHOLD
    
    config = {
        'TELEGRAM_BOT_TOKEN': '',
        'TELEGRAM_CHAT_ID': '',
        'LOG_FILE_PATH': DEFAULT_LOG_PATH
    }
    
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' in line:
                        k, v = line.split('=', 1)
                        key_strip = k.strip()
                        val = v.strip().strip('"').strip("'")
                        config[key_strip] = val
                        
                        with config_lock:
                            if key_strip == 'WHITELIST_IPS':
                                for ip in val.split(','):
                                    ip_clean = ip.strip()
                                    if ip_clean:
                                        WHITELISTED_IPS.add(ip_clean)
                            elif key_strip == 'BLOCK_DURATION':
                                BLOCK_DURATION = int(val)
                            elif key_strip == 'MAX_ATTEMPTS_PER_IP':
                                MAX_ATTEMPTS_PER_IP = int(val)
                            elif key_strip == 'DASHBOARD_API_KEY':
                                DASHBOARD_API_KEY = val
                            elif key_strip == 'DASHBOARD_BIND_IP':
                                DASHBOARD_BIND_IP = val
                            elif key_strip == 'DASHBOARD_ALLOW_EXTERNAL':
                                DASHBOARD_ALLOW_EXTERNAL = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'DASHBOARD_ALLOWED_IPS':
                                DASHBOARD_ALLOWED_IPS = {ip.strip() for ip in val.split(',') if ip.strip()}
                            elif key_strip == 'SSL_CERT_PATH':
                                SSL_CERT_PATH = val
                            elif key_strip == 'SSL_KEY_PATH':
                                SSL_KEY_PATH = val
                            elif key_strip == 'SQLI_THRESHOLD':
                                SQLI_THRESHOLD = int(val)
                            elif key_strip == 'XSS_THRESHOLD':
                                XSS_THRESHOLD = int(val)
                            elif key_strip == 'ENABLE_SQLI':
                                ENABLE_SQLI = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_XSS':
                                ENABLE_XSS = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_RCE':
                                ENABLE_RCE = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_TRAVERSAL':
                                ENABLE_TRAVERSAL = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_SCANNER':
                                ENABLE_SCANNER = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_SSRF':
                                ENABLE_SSRF = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_XXE':
                                ENABLE_XXE = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_REDIRECT':
                                ENABLE_REDIRECT = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_JWT':
                                ENABLE_JWT = val.lower() in ('true', '1', 'yes')
                            elif key_strip == 'ENABLE_ANOMALY':
                                ENABLE_ANOMALY = val.lower() in ('true', '1', 'yes')
        except Exception as e:
            print(f"Error reading config file: {e}")
            
    with config_lock:
        if not DASHBOARD_ALLOW_EXTERNAL:
            DASHBOARD_BIND_IP = "127.0.0.1"  # Bound strictly to localhost
            
    return config

def save_api_key_to_config(api_key):
    try:
        config_dir = os.path.dirname(CONFIG_PATH)
        if config_dir and not os.path.exists(config_dir):
            os.makedirs(config_dir, exist_ok=True)
            
        lines = []
        key_exists = False
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
                for line in f:
                    if line.strip().startswith('DASHBOARD_API_KEY='):
                        lines.append(f'DASHBOARD_API_KEY="{api_key}"\n')
                        key_exists = True
                    else:
                        lines.append(line)
                        
        if not key_exists:
            if lines and not lines[-1].endswith('\n'):
                lines.append('\n')
            lines.append(f'DASHBOARD_API_KEY="{api_key}"\n')
            
        with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
            f.writelines(lines)
            
        print(f"Persistent DASHBOARD_API_KEY successfully saved to {CONFIG_PATH}")
        log_audit_action("CONFIG_CHANGE", "N/A", f"Saved persistent DASHBOARD_API_KEY to config file", actor="system_daemon")
    except Exception as e:
        print(f"Failed to persist DASHBOARD_API_KEY to config: {e}")

# ----------------- Firewall Backend Abstraction Layer -----------------

class FirewallBackend:
    def block_ip(self, ip, reason):
        raise NotImplementedError
    def unblock_ip(self, ip):
        raise NotImplementedError
    def is_blocked(self, ip):
        raise NotImplementedError

class UFWBackend(FirewallBackend):
    def is_blocked(self, ip):
        try:
            res = subprocess.run(["ufw", "status"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
            return ip in res.stdout
        except Exception:
            return False

    def block_ip(self, ip, reason):
        if self.is_blocked(ip):
            return "موقوف حالياً"
        try:
            res = subprocess.run(["ufw", "insert", "1", "deny", "from", ip, "to", "any"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                return "تم الحظر بنجاح (UFW)"
        except Exception as e:
            print(f"[FW] UFW block error: {e}")
        return None

    def unblock_ip(self, ip):
        try:
            res = subprocess.run(["ufw", "delete", "deny", "from", ip], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            return res.returncode == 0
        except Exception as e:
            print(f"[FW] UFW unblock error: {e}")
            return False

class IPTablesBackend(FirewallBackend):
    def is_blocked(self, ip):
        try:
            res = subprocess.run(["iptables", "-C", "INPUT", "-s", ip, "-j", "DROP"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
            return res.returncode == 0
        except Exception:
            return False

    def block_ip(self, ip, reason):
        if self.is_blocked(ip):
            return "موقوف حالياً"
        try:
            res = subprocess.run(["iptables", "-I", "INPUT", "1", "-s", ip, "-j", "DROP"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                return "تم الحظر بنجاح (IPTables)"
        except Exception as e:
            print(f"[FW] IPTables block error: {e}")
        return None

    def unblock_ip(self, ip):
        try:
            res = subprocess.run(["iptables", "-D", "INPUT", "-s", ip, "-j", "DROP"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            return res.returncode == 0
        except Exception as e:
            print(f"[FW] IPTables unblock error: {e}")
            return False

def _validate_ip(ip: str) -> str:
    """Validate and normalise an IP address string.

    Raises ValueError if the string is not a valid IPv4/IPv6 address.
    Returns the compressed canonical representation so it is safe to
    interpolate into firewall command arguments.
    """
    return str(ipaddress.ip_address(ip))  # raises ValueError for invalid input

class NFTablesBackend(FirewallBackend):
    def __init__(self):
        try:
            subprocess.run(["nft", "add", "table", "ip", "filter"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
            subprocess.run(["nft", "add", "chain", "ip", "filter", "input", "{ type filter hook input priority 0 ; }"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
            subprocess.run(["nft", "add", "set", "ip", "filter", "security_monitor_blocklist", "{ type ipv_addr ; }"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
            res = subprocess.run(["nft", "list", "chain", "ip", "filter", "input"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=2)
            if "security_monitor_blocklist" not in res.stdout:
                subprocess.run(["nft", "add", "rule", "ip", "filter", "input", "ip", "saddr", "@security_monitor_blocklist", "drop"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2)
        except Exception as e:
            print(f"[FW] NFTables initialization warning: {e}")

    def is_blocked(self, ip):
        try:
            safe_ip = _validate_ip(ip)  # Prevent command injection
            res = subprocess.run(["nft", "list", "set", "ip", "filter", "security_monitor_blocklist"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
            return safe_ip in res.stdout
        except ValueError:
            print(f"[FW] NFTables is_blocked: invalid IP rejected: {ip!r}")
            return False
        except Exception:
            return False

    def block_ip(self, ip, reason):
        try:
            safe_ip = _validate_ip(ip)  # Raise ValueError for invalid/malicious input
        except ValueError:
            print(f"[FW] NFTables block_ip: invalid IP rejected: {ip!r}")
            return None
        if self.is_blocked(safe_ip):
            return "موقوف حالياً"
        try:
            # Pass IP as a separate list element — never shell-interpolated
            res = subprocess.run(
                ["nft", "add", "element", "ip", "filter", "security_monitor_blocklist", f"{{ {safe_ip} }}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5
            )
            if res.returncode == 0:
                return "تم الحظر بنجاح (NFTables)"
        except Exception as e:
            print(f"[FW] NFTables block error: {e}")
        return None

    def unblock_ip(self, ip):
        try:
            safe_ip = _validate_ip(ip)  # Prevent command injection
        except ValueError:
            print(f"[FW] NFTables unblock_ip: invalid IP rejected: {ip!r}")
            return False
        try:
            res = subprocess.run(
                ["nft", "delete", "element", "ip", "filter", "security_monitor_blocklist", f"{{ {safe_ip} }}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5
            )
            return res.returncode == 0
        except Exception as e:
            print(f"[FW] NFTables unblock error: {e}")
            return False

def get_firewall_backend():
    """Detect the available firewall backend using shutil.which (no subprocess overhead)."""
    if shutil.which("ufw"):
        print("[FW] Detected UFW firewall backend.")
        return UFWBackend()
    elif shutil.which("nft"):
        print("[FW] Detected NFTables firewall backend.")
        return NFTablesBackend()
    elif shutil.which("iptables"):
        print("[FW] Detected IPTables firewall backend.")
        return IPTablesBackend()
    else:
        print("[FW] No supported firewall command found (UFW/NFTables/IPTables). Running in monitoring-only mode.")
        return FirewallBackend()

firewall_backend = get_firewall_backend()

# ----------------- Core Logic & Whitelisting -----------------

def is_whitelisted_ip(ip):
    if ip in WHITELISTED_IPS:
        return True
    if ip in ('127.0.0.1', '::1'):
        return True
    if ip.startswith('10.') or ip.startswith('192.168.'):
        return True
    if ip.startswith('172.'):
        try:
            parts = ip.split('.')
            if 16 <= int(parts[1]) <= 31:
                return True
        except Exception:
            pass
    return False

# Real IP Extraction supporting Reverse Proxy (Cloudflare / X-Forwarded-For) (Phase 3 Optimization)
def extract_real_ip(parsed, raw_line):
    client_ip = parsed['ip']
    
    # Extract all IPv4 addresses from the entire raw line
    all_ips = re.findall(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', raw_line)
    for ip in all_ips:
        if ip != client_ip and not is_whitelisted_ip(ip):
            # Exclude private subnets
            if not (ip.startswith('127.') or ip.startswith('10.') or ip.startswith('192.168.') or ip.startswith('172.16.') or ip.startswith('172.17.') or ip.startswith('172.18.') or ip.startswith('172.19.') or ip.startswith('172.2') or ip.startswith('172.3') or ip.startswith('169.254.')):
                return ip
    return client_ip

def get_geoip_info(ip):
    if is_whitelisted_ip(ip):
        return {'country': 'Local Link', 'city': 'Private IP', 'isp': 'N/A'}
        
    cached = geoip_cache.get(ip)
    if cached:
        return cached
        
    row = execute_read_one("SELECT country, city, isp FROM geoip_cache WHERE ip = ?", (ip,))
    if row:
        res = {'country': row[0], 'city': row[1], 'isp': row[2]}
        geoip_cache.set(ip, res)
        return res

    res = None
    # Provider 1: ip-api.com
    try:
        url = f"http://ip-api.com/json/{ip}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=2) as response:
            data = json.loads(response.read().decode('utf-8'))
            if data.get('status') == 'success':
                res = {
                    'country': data.get('country', 'Unknown'),
                    'city': data.get('city', 'Unknown'),
                    'isp': data.get('isp', 'Unknown')
                }
    except Exception as e:
        print(f"GeoIP Provider 1 (ip-api.com) failed for {ip}: {e}")

    # Provider 2: freeipapi.com
    if not res:
        try:
            url = f"https://freeipapi.com/api/json/{ip}"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=2) as response:
                data = json.loads(response.read().decode('utf-8'))
                res = {
                    'country': data.get('countryName', 'Unknown'),
                    'city': data.get('cityName', 'Unknown'),
                    'isp': data.get('isp', 'Unknown')
                }
        except Exception as e:
            print(f"GeoIP Provider 2 (freeipapi.com) failed for {ip}: {e}")

    # Provider 3: ipapi.co
    if not res:
        try:
            url = f"https://ipapi.co/{ip}/json/"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=2) as response:
                data = json.loads(response.read().decode('utf-8'))
                if 'error' not in data:
                    res = {
                        'country': data.get('country_name', 'Unknown'),
                        'city': data.get('city', 'Unknown'),
                        'isp': data.get('org', 'Unknown')
                    }
        except Exception as e:
            print(f"GeoIP Provider 3 (ipapi.co) failed for {ip}: {e}")

    if not res:
        res = {'country': 'Unknown', 'city': 'Unknown', 'isp': 'Unknown'}

    geoip_cache.set(ip, res)
    query = "INSERT OR REPLACE INTO geoip_cache (ip, country, city, isp, cached_at) VALUES (?, ?, ?, ?, ?)"
    queue_db_write(query, (ip, res['country'], res['city'], res['isp'], time.time()))
    return res

def block_ip(ip, reason, actor="system_daemon"):
    if is_whitelisted_ip(ip):
        print(f"IP {ip} is whitelisted. Skipping firewall block.")
        return "تم التجاوز (عنوان موثوق)"
    
    ban_status = firewall_backend.block_ip(ip, reason)
    if ban_status and "تم الحظر" in ban_status:
        add_blocked_ip_to_db(ip, BLOCK_DURATION, reason, actor=actor)
    return ban_status if ban_status else "فشل الحظر"

def unblock_ip(ip, actor="system_daemon"):
    success = firewall_backend.unblock_ip(ip)
    if success:
        remove_blocked_ip_from_db(ip, actor=actor)
        cfg = load_config()
        msg = f"🔓 <b>تحديث جدار الحماية (Auto Unban):</b>\n• تم إلغاء حظر العنوان IP: <code>{html.escape(ip)}</code> تلقائياً بعد انتهاء فترة الحظر."
        send_telegram_alert(cfg['TELEGRAM_BOT_TOKEN'], cfg['TELEGRAM_CHAT_ID'], msg)
        return True
    return False

def unban_worker():
    print("Unban background worker thread started.")
    while not shutdown_event.is_set():
        try:
            now = time.time()
            expired = execute_read("SELECT ip FROM blocked_ips WHERE unban_at <= ?", (now,))
            for (ip,) in expired:
                unblock_ip(ip)
        except Exception as e:
            print(f"Error in unban worker loop: {e}")
            
        for _ in range(20):
            if shutdown_event.is_set():
                break
            time.sleep(0.5)

# ----------------- Alert Notification & Structured Logs -----------------

def send_telegram_alert(token, chat_id, message, parse_mode='HTML'):
    if not token or not chat_id or 'YOUR_TELEGRAM' in token or 'YOUR_TELEGRAM' in chat_id:
        print("Telegram not configured. Skipping alert dispatch.")
        return False
    try:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        payload = {
            'chat_id': chat_id,
            'text': message,
            'parse_mode': parse_mode
        }
        data = urllib.parse.urlencode(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            res = json.loads(response.read().decode('utf-8'))
            return res.get('ok', False)
    except Exception as e:
        print(f"Telegram dispatch failed: {e}")
        return False

def log_alert_structured(ip, threat_type, path, method, status, agent, geo):
    log_entry = {
        "timestamp": time.time(),
        "ip": ip,
        "threat_type": threat_type,
        "path": path,
        "method": method,
        "status_code": status,
        "user_agent": agent,
        "geo": geo
    }
    try:
        with open(ALERT_LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(json.dumps(log_entry) + '\n')
    except Exception as e:
        print(f"Failed to write structured log: {e}")

def queue_alert(ip, threat_type, path, method, status, agent, geo):
    now = time.time()
    buf = alert_buffer.get(ip)
    if not buf:
        alert_buffer.set(ip, {
            'first_seen': now,
            'last_update': now,
            'threats': {threat_type},
            'paths': {path},
            'geo': geo,
            'agent': agent,
            'status_codes': {status},
            'methods': {method},
            'count': 1
        })
    else:
        buf['last_update'] = now
        if len(buf['threats']) < 10:
            buf['threats'].add(threat_type)
        if len(buf['paths']) < 10:
            buf['paths'].add(path)
        if len(buf['status_codes']) < 10:
            buf['status_codes'].add(status)
        if len(buf['methods']) < 10:
            buf['methods'].add(method)
        buf['count'] += 1
        alert_buffer.set(ip, buf)

def alert_sender_worker():
    print("Alert aggregation worker thread started.")
    while not shutdown_event.is_set():
        try:
            now = time.time()
            to_send = []
            
            ips = alert_buffer.keys()
            for ip in ips:
                buf = alert_buffer.get(ip)
                if buf and ((now - buf['last_update'] >= 3) or (now - buf['first_seen'] >= 8)):
                    to_send.append((ip, buf))
                    alert_buffer.remove(ip)
            
            for ip, buf in to_send:
                threats_list = list(buf['threats'])
                primary_threat = threats_list[0]
                
                advice = None
                for k, v in REMEDIATION_ADVICE.items():
                    if k in primary_threat:
                        advice = v
                        break
                if not advice:
                    advice = {
                        "analysis": "تم رصد محاولات مشبوهة متعددة تهدف للعبث بموارد الخادم.",
                        "remediation": "يرجى مراجعة الكود البرمجي وتنقية المدخلات وتأمين الخادم."
                    }
                
                is_currently_blocked = execute_read_one("SELECT 1 FROM blocked_ips WHERE ip = ?", (ip,)) is not None
                firewall_text = "🚫 تم الحظر تلقائياً (IP Banned)" if is_currently_blocked else "⚠️ مراقبة نشطة"
                
                escaped_ip = html.escape(ip)
                escaped_country = html.escape(buf['geo'].get('country', 'Unknown'))
                escaped_city = html.escape(buf['geo'].get('city', 'Unknown'))
                escaped_isp = html.escape(buf['geo'].get('isp', 'Unknown'))
                escaped_agent = html.escape(buf.get('agent', 'N/A'))
                
                paths_summary = ""
                for p in list(buf['paths'])[:5]:
                    paths_summary += f"  - <code>{html.escape(p)}</code>\n"
                if len(buf['paths']) > 5:
                    paths_summary += f"  - ... وعدد {len(buf['paths']) - 5} مسارات أخرى.\n"

                threats_str = html.escape(", ".join(threats_list))
                methods_str = html.escape(", ".join(buf['methods']))
                status_codes_str = html.escape(", ".join(buf['status_codes']))
                
                msg = (
                    f"🚨 <b>كشف محاولة اختراق نشطة (تنبيه مجمع)!</b>\n\n"
                    f"👤 <b>بيانات المهاجم:</b>\n"
                    f"• <b>العنوان IP:</b> <code>{escaped_ip}</code>\n"
                    f"• <b>الدولة/المدينة:</b> <code>{escaped_country} - {escaped_city}</code>\n"
                    f"• <b>المزود (ISP):</b> <code>{escaped_isp}</code>\n"
                    f"• <b>الجهاز (User-Agent):</b> <code>{escaped_agent}</code>\n\n"
                    f"🛡️ <b>تفاصيل الهجمات:</b>\n"
                    f"• <b>إجمالي الطلبات:</b> <code>{buf['count']}</code>\n"
                    f"• <b>نوع التهديدات:</b> <code>{threats_str}</code>\n"
                    f"• <b>المسارات المستهدفة:</b>\n{paths_summary}"
                    f"• <b>الأكواد والطلبات:</b> <code>{methods_str}</code> | <code>{status_codes_str}</code>\n"
                    f"• <b>حالة جدار الحماية:</b> <code>{firewall_text}</code>\n\n"
                    f"🔍 <b>تحليل الهجوم وكيف تم:</b>\n"
                    f"{advice['analysis']}\n\n"
                    f"💡 <b>طريقة الحل الجذري والوقاية:</b>\n"
                    f"{advice['remediation']}"
                )
                
                cfg = load_config()
                send_telegram_alert(cfg['TELEGRAM_BOT_TOKEN'], cfg['TELEGRAM_CHAT_ID'], msg)
                
                # Write structured JSON log
                log_alert_structured(ip, primary_threat, list(buf['paths'])[0], list(buf['methods'])[0], list(buf['status_codes'])[0], buf['agent'], buf['geo'])
                print(f"[DISPATCH] Sent aggregated HTML alert summary for {ip} (count: {buf['count']})")
        except Exception as e:
            print(f"Error in alert sender loop: {e}")
            
        for _ in range(10):
            if shutdown_event.is_set():
                break
            time.sleep(0.5)

# ----------------- Anomaly Detection Engine -----------------

def calculate_entropy(s):
    if not s:
        return 0.0
    total = len(s)
    counts = collections.Counter(s)
    entropy = 0.0
    for count in counts.values():
        p = count / total
        entropy -= p * math.log2(p)
    return entropy

def check_statistical_anomaly(ip, path):
    with baseline_lock:
        if len(normal_request_features) < MIN_BASELINE_SAMPLES:
            return None
            
        length = len(path)
        entropy = calculate_entropy(path)
        
        lengths = [f[0] for f in normal_request_features]
        entropies = [f[1] for f in normal_request_features]
        
        mean_len = sum(lengths) / len(lengths)
        var_len = sum((x - mean_len) ** 2 for x in lengths) / len(lengths)
        std_len = math.sqrt(var_len)
        
        mean_ent = sum(entropies) / len(entropies)
        var_ent = sum((x - mean_ent) ** 2 for x in entropies) / len(entropies)
        std_ent = math.sqrt(var_ent)
        
    # Clamp standard deviations to avoid division by zero or high sensitivity
    effective_std_len = max(std_len, 5.0)
    effective_std_ent = max(std_ent, 0.2)
    
    z_len = (length - mean_len) / effective_std_len
    z_ent = (entropy - mean_ent) / effective_std_ent
    
    # Trigger if request deviates significantly from learned norm
    if z_len > 5.0:
        return f"Anomalous Traffic (Statistical URL Length Outlier, Z-score: {z_len:.1f})"
        
    if z_ent > 4.5:
        return f"Anomalous Traffic (Statistical Entropy Outlier, Z-score: {z_ent:.1f})"
        
    return None

def check_behavioral_anomaly(ip, path, status):
    current_time = time.time()
    
    if len(path) > 1000:
        return "Anomalous Traffic (URL Length Exceeded)"
        
    hist = client_history.get(ip, collections.deque(maxlen=200))
    try:
        status_code = int(status)
    except Exception:
        status_code = 200
        
    hist.append((current_time, len(path), status_code))
    client_history.set(ip, hist)
    
    # Volume/Flood anomaly (>150 reqs in 10s)
    recent_reqs = [item for item in hist if current_time - item[0] <= 10]
    if len(recent_reqs) > 150:
        hist.clear()
        client_history.set(ip, hist)
        return "Anomalous Traffic (Flood Request Pattern)"
        
    # HTTP Failure Ratio anomaly (>70% non-200 in last 60s, min 15 reqs)
    recent_60s = [item for item in hist if current_time - item[0] <= 60]
    if len(recent_60s) >= 15:
        failures = sum(1 for item in recent_60s if item[2] >= 400)
        failure_ratio = failures / len(recent_60s)
        if failure_ratio > 0.70:
            hist.clear()
            client_history.set(ip, hist)
            return f"Anomalous Traffic (High HTTP Failure Ratio: {failure_ratio:.0%})"
            
    return None

# ----------------- Nginx Log Scanner -----------------

def parse_nginx_line(line):
    pattern = r'^([^ ]+) - ([^ ]+) \[(.*?)\] "([^ ]+) ([^ ]+) (.*?)" (\d+) (\d+) "([^"]*)" "([^"]*)"'
    match = re.match(pattern, line)
    if match:
        return {
            'ip': match.group(1),
            'timestamp': match.group(3),
            'method': match.group(4),
            'path': match.group(5),
            'status': match.group(7),
            'agent': match.group(10)
        }
    return None

def scan_line(line, config):
    parsed = parse_nginx_line(line)
    if not parsed:
        return

    path = parsed['path']
    decoded_path = recursive_url_decode(path)
    decoded_path = attempt_base64_decode_url(decoded_path)
    
    status = parsed['status']
    ip = extract_real_ip(parsed, line)  # Real IP Detection supporting Cloudflare proxy (Phase 3 Upgrade)
    agent = parsed['agent']
    method = parsed['method']

    threat_type = None

    # 1. Behavioral Anomaly Checks
    if ENABLE_ANOMALY:
        anomaly = check_behavioral_anomaly(ip, path, status)
        if anomaly:
            threat_type = anomaly
            
    # 2. Statistical Outlier Check
    if not threat_type and ENABLE_ANOMALY:
        stat_anomaly = check_statistical_anomaly(ip, path)
        if stat_anomaly:
            threat_type = stat_anomaly

    # 3. Signature: Check User Agent for automated scanner tools (Pre-filtered)
    if not threat_type and ENABLE_SCANNER:
        agent_lower = agent.lower()
        # Fast lookup before running heavy UA regex
        scanner_ua_kws = ['sqlmap', 'nmap', 'nikto', 'acunetix', 'dirbuster', 'gobuster', 'censys', 'shodan', 'masscan', 'w3af', 'hydra', 'nessus', 'zgrab', 'netsparker', 'openvas', 'nuclei', 'nimbostratus', 'arachni']
        if any(kw in agent_lower for kw in scanner_ua_kws):
            if SUSPICIOUS_UA_PATTERN.search(agent):
                threat_type = "Suspicious User-Agent / Scanner Bot"

    # 4. Signature: Check SQL Injection (Scoring-based & Pre-filtered for CPU Optimization)
    if not threat_type and ENABLE_SQLI:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_SQLI_KEYWORDS):
            sqli_score, sqli_matches = calculate_threat_score(decoded_path, SQLI_SCORING)
            if sqli_score >= SQLI_THRESHOLD:
                threat_type = "SQL Injection (SQLi)"
                print(f"[SCORE] SQLi threat confirmed with score {sqli_score} (Matches: {sqli_matches})")

    # 5. Signature: Check Cross-Site Scripting (Scoring-based & Pre-filtered)
    if not threat_type and ENABLE_XSS:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_XSS_KEYWORDS):
            xss_score, xss_matches = calculate_threat_score(decoded_path, XSS_SCORING)
            if xss_score >= XSS_THRESHOLD:
                threat_type = "Cross-Site Scripting (XSS)"
                print(f"[SCORE] XSS threat confirmed with score {xss_score} (Matches: {xss_matches})")

    # 6. Check Path Traversal (Pre-filtered)
    if not threat_type and ENABLE_TRAVERSAL:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_TRAVERSAL_KEYWORDS):
            if TRAVERSAL_PATTERN.search(decoded_path):
                threat_type = "Path Traversal / LFI"

    # 7. Check Remote Code Execution / Command Injection (Pre-filtered)
    if not threat_type and ENABLE_RCE:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_RCE_KEYWORDS):
            if RCE_PATTERN.search(decoded_path):
                threat_type = "Remote Code Execution (RCE)"

    # 8. Check SSRF (Pre-filtered)
    if not threat_type and ENABLE_SSRF:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_SSRF_KEYWORDS):
            if SSRF_PATTERN.search(decoded_path):
                threat_type = "SSRF"

    # 9. Check XXE (Pre-filtered)
    if not threat_type and ENABLE_XXE:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_XXE_KEYWORDS):
            if XXE_PATTERN.search(decoded_path):
                threat_type = "XXE"

    # 10. Check Open Redirect (Pre-filtered)
    if not threat_type and ENABLE_REDIRECT:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_REDIRECT_KEYWORDS):
            if REDIRECT_PATTERN.search(decoded_path):
                threat_type = "Open Redirect"

    # 11. Check JWT Abuse (Pre-filtered)
    if not threat_type and ENABLE_JWT:
        decoded_path_lower = decoded_path.lower()
        if any(kw in decoded_path_lower for kw in QUICK_JWT_KEYWORDS):
            if JWT_ABUSE_PATTERN.search(decoded_path):
                threat_type = "JWT Abuse"

    # 12. Check Scanner scans / access to sensitive files
    if not threat_type and ENABLE_SCANNER and status in ('404', '403', '401'):
        if SCANNER_PATTERN.search(decoded_path):
            threat_type = "Vulnerability / Scanner Scan"

    # 13. Check Fuzzing / Brute-force rate tracker
    is_fuzzing = False
    if not threat_type and status in ('404', '403'):
        current_time = time.time()
        ip_attempts = attack_tracker.get(ip, collections.deque(maxlen=100))
        ip_attempts.append(current_time)
        recent_attempts = [t for t in ip_attempts if current_time - t <= 10]
        ip_attempts.clear()
        ip_attempts.extend(recent_attempts)
        attack_tracker.set(ip, ip_attempts)
        
        if len(ip_attempts) > 15:
            threat_type = "Directory Fuzzing / Brute-Force"
            is_fuzzing = True

    # Learn the normal request baseline if it's clean and returning successful code
    if not threat_type and status in ('200', '302', '304') and ENABLE_ANOMALY:
        with baseline_lock:
            normal_request_features.append((len(path), calculate_entropy(path)))

    if threat_type:
        geo = get_geoip_info(ip)
        
        log_attack_to_db(ip, threat_type, path, method, status, agent, geo)
        
        now = time.time()
        count = 0
        try:
            row = execute_read_one("SELECT COUNT(*) FROM attacks WHERE ip = ? AND timestamp >= ?", (ip, now - 60))
            if row:
                count = row[0]
        except Exception:
            pass
            
        ban_status = "مراقب"
        if (count >= MAX_ATTEMPTS_PER_IP or is_fuzzing) and not is_whitelisted_ip(ip):
            ban_status = block_ip(ip, f"Exceeded MAX_ATTEMPTS ({count}) or Fuzzing rate")
            
        queue_alert(ip, threat_type, path, method, status, agent, geo)
        print(f"[ALERT] {threat_type} detected from {ip} on {path}. Active count: {count}. Firewall: {ban_status}")

# Completed main tail loop (Log Rotation & Inode tracking) (Phase 3 Upgrade)
def tail_log_file(file_path, config):
    print(f"Starting Nginx log security monitor on {file_path}...")
    while not shutdown_event.is_set():
        try:
            if not os.path.exists(file_path):
                time.sleep(1)
                continue
                
            current_inode = os.stat(file_path).st_ino
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(0, os.SEEK_END)
                while not shutdown_event.is_set():
                    line = f.readline()
                    if not line:
                        try:
                            new_stat = os.stat(file_path)
                            if new_stat.st_ino != current_inode:
                                print(f"Log rotation detected (inode changed from {current_inode} to {new_stat.st_ino}). Re-opening log...")
                                # Consume rest of old file
                                for remaining in f.readlines():
                                    scan_line(remaining, config)
                                break
                        except FileNotFoundError:
                            pass
                        time.sleep(0.1)
                        continue
                    scan_line(line, config)
        except Exception as e:
            print(f"Error tailing log file: {e}")
            time.sleep(2)

def calculate_threat_score(text, scoring_rules):
    score = 0
    matched_rules = []
    for pattern, weight in scoring_rules:
        if pattern.search(text):
            score += weight
            matched_rules.append(pattern.pattern)
    return score, matched_rules

# ----------------- Dashboard HTTP JSON API Server -----------------

class DashboardHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Mute standard HTTP logging to stdout
        return

    def send_response_json(self, status_code, data):
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        # Security Headers
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none';")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def send_error_json(self, status_code, message):
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        # Security Headers
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none';")
        self.end_headers()
        self.wfile.write(json.dumps({"error": message}).encode('utf-8'))

    def check_auth_and_rate_limit(self, parsed_url):
        client_ip = self.client_address[0]
        now = time.time()
        
        # 1. IP Access Control List (Allowed IPs)
        with config_lock:
            allowed_ips = DASHBOARD_ALLOWED_IPS
        if allowed_ips and client_ip not in allowed_ips:
            log_audit_action("DASHBOARD_IP_BLOCKED", client_ip, "IP not in DASHBOARD_ALLOWED_IPS list", actor="dashboard_auth")
            self.send_error_json(403, "Forbidden. Client IP is not allowed to access this dashboard.")
            return False

        # 2. Rate Limiting Check (5 reqs/sec)
        req_times = dashboard_rate_tracker.get(client_ip, [])
        req_times = [t for t in req_times if now - t <= 1.0]
        if len(req_times) >= 5:
            self.send_error_json(429, "Too Many Requests. Rate limit exceeded.")
            return False
        req_times.append(now)
        dashboard_rate_tracker.set(client_ip, req_times)
        
        # 3. Lockout Check (brute force protection)
        lockout_info = dashboard_lockout_tracker.get(client_ip)
        if lockout_info:
            failed_count, lockout_end = lockout_info
            if now < lockout_end:
                self.send_error_json(429, "Too many authentication failures. Locked out.")
                return False
                
        # 4. Authentication Verification (Header Only Hardening)
        api_key_header = self.headers.get('X-API-Key')
        
        authenticated = False
        if api_key_header and api_key_header == DASHBOARD_API_KEY:
            authenticated = True
            
        if not authenticated:
            failed_count = 0
            lockout_info = dashboard_lockout_tracker.get(client_ip)
            if lockout_info:
                failed_count = lockout_info[0]
            failed_count += 1
            
            lockout_end = 0
            if failed_count >= 5:
                lockout_end = now + 600  # 10 minutes lockout
                print(f"[AUTH] IP {client_ip} locked out from dashboard for 10 minutes (5 failed auth attempts)")
                log_audit_action("DASHBOARD_LOCKOUT", client_ip, "IP temporarily locked out from dashboard due to brute force", actor="dashboard_auth")
            
            dashboard_lockout_tracker.set(client_ip, (failed_count, lockout_end))
            log_audit_action("DASHBOARD_LOGIN_FAILED", client_ip, "Failed authentication attempt (invalid X-API-Key)", actor="dashboard_auth")
            
            self.send_response(401)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('X-Frame-Options', 'DENY')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none';")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Unauthorized. Invalid or missing X-API-Key Header."}).encode('utf-8'))
            return False
            
        # Reset failed attempts on success
        dashboard_lockout_tracker.remove(client_ip)
        
        # Log successful auth only once per 5 minutes per IP to avoid database spam
        last_auth = successful_auth_ips.get(client_ip, 0)
        if now - last_auth > 300:
            log_audit_action("DASHBOARD_LOGIN_SUCCESS", client_ip, "Successful authentication", actor="dashboard_auth")
            successful_auth_ips.set(client_ip, now)
            
        return True

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        
        # Health check endpoint - Excluded from auth
        if parsed_url.path == '/health':
            health_status = {
                "status": "healthy",
                "database": "connected" if os.path.exists(DB_PATH) else "disconnected",
                "threads": {
                    "db_writer": t_db.is_alive() if 't_db' in globals() else False,
                    "unban": t_unban.is_alive() if 't_unban' in globals() else False,
                    "alert_aggregator": t_alert.is_alive() if 't_alert' in globals() else False
                }
            }
            self.send_response_json(200, health_status)
            return
            
        # Authentication & Rate Limit checks
        if not self.check_auth_and_rate_limit(parsed_url):
            return
            
        if parsed_url.path == '/attacks':
            try:
                rows = execute_read("SELECT * FROM attacks ORDER BY timestamp DESC LIMIT 100", row_factory=sqlite3.Row)
                data = [dict(r) for r in rows]
                self.send_response_json(200, data)
            except Exception as e:
                self.send_error_json(500, str(e))
                
        elif parsed_url.path == '/blocked_ips':
            try:
                rows = execute_read("SELECT * FROM blocked_ips ORDER BY blocked_at DESC", row_factory=sqlite3.Row)
                data = [dict(r) for r in rows]
                self.send_response_json(200, data)
            except Exception as e:
                self.send_error_json(500, str(e))

        elif parsed_url.path == '/audit_logs':
            try:
                rows = execute_read("SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 100", row_factory=sqlite3.Row)
                data = [dict(r) for r in rows]
                self.send_response_json(200, data)
            except Exception as e:
                self.send_error_json(500, str(e))
                
        elif parsed_url.path == '/config':
            try:
                data = {
                    "max_attempts_per_ip": MAX_ATTEMPTS_PER_IP,
                    "block_duration": BLOCK_DURATION,
                    "dashboard_bind_ip": DASHBOARD_BIND_IP
                }
                self.send_response_json(200, data)
            except Exception as e:
                self.send_error_json(500, str(e))
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found. Use /attacks, /blocked_ips, /audit_logs, or /config")

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        
        # Authentication & Rate Limit checks
        if not self.check_auth_and_rate_limit(parsed_url):
            return
            
        client_ip = self.client_address[0]
        actor_name = f"admin_from_{client_ip}"
            
        if parsed_url.path == '/block':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length).decode('utf-8')
                data = json.loads(post_data)
                ip = data.get('ip')
                reason = data.get('reason', 'Manual Block via API')
                
                if not ip:
                    self.send_error_json(400, "Missing 'ip' parameter")
                    return
                    
                ban_status = block_ip(ip, reason, actor=actor_name)
                self.send_response_json(200, {"success": True, "message": f"Block triggered: {ban_status}"})
            except Exception as e:
                self.send_error_json(500, str(e))
                
        elif parsed_url.path == '/unblock':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length).decode('utf-8')
                data = json.loads(post_data)
                ip = data.get('ip')
                
                if not ip:
                    self.send_error_json(400, "Missing 'ip' parameter")
                    return
                    
                success = unblock_ip(ip, actor=actor_name)
                self.send_response_json(200, {"success": success, "message": "Unblock operation processed"})
            except Exception as e:
                self.send_error_json(500, str(e))
                
        elif parsed_url.path == '/config':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length).decode('utf-8')
                data = json.loads(post_data)
                
                global MAX_ATTEMPTS_PER_IP, BLOCK_DURATION
                changes = []
                
                if 'max_attempts_per_ip' in data:
                    new_val = int(data['max_attempts_per_ip'])
                    changes.append(f"MAX_ATTEMPTS_PER_IP: {MAX_ATTEMPTS_PER_IP} -> {new_val}")
                    MAX_ATTEMPTS_PER_IP = new_val
                    
                if 'block_duration' in data:
                    new_val = int(data['block_duration'])
                    changes.append(f"BLOCK_DURATION: {BLOCK_DURATION} -> {new_val}")
                    BLOCK_DURATION = new_val
                
                if not changes:
                    self.send_response_json(200, {"success": True, "message": "No configuration parameters modified"})
                    return
                    
                # Persist config back to file
                lines = []
                if os.path.exists(CONFIG_PATH):
                    with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
                        for line in f:
                            cleaned = line.strip()
                            if cleaned.startswith('MAX_ATTEMPTS_PER_IP='):
                                lines.append(f'MAX_ATTEMPTS_PER_IP={MAX_ATTEMPTS_PER_IP}\n')
                            elif cleaned.startswith('BLOCK_DURATION='):
                                lines.append(f'BLOCK_DURATION={BLOCK_DURATION}\n')
                            else:
                                lines.append(line)
                                
                with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
                    f.writelines(lines)
                    
                change_log = ", ".join(changes)
                log_audit_action("CHANGE_CONFIG", "N/A", f"Configuration updated: {change_log}", actor=actor_name)
                self.send_response_json(200, {"success": True, "message": f"Config updated successfully: {change_log}"})
            except Exception as e:
                self.send_error_json(500, str(e))
                
        elif parsed_url.path == '/backup':
            try:
                backup_path = '/var/log/security_monitor_backup.db'
                src = get_db_connection()
                dst = sqlite3.connect(backup_path)
                with dst:
                    src.backup(dst)
                dst.close()
                src.close()
                log_audit_action("DATABASE_BACKUP", client_ip, "Database backed up successfully", actor=actor_name)
                self.send_response_json(200, {"success": True, "message": f"Database backed up to {backup_path}"})
            except Exception as e:
                self.send_error_json(500, f"Backup failed: {e}")
                
        elif parsed_url.path == '/restore':
            try:
                backup_path = '/var/log/security_monitor_backup.db'
                if not os.path.exists(backup_path):
                    self.send_error_json(400, "Backup file not found. Perform a backup first.")
                    return
                dst = get_db_connection()
                src = sqlite3.connect(backup_path)
                with dst:
                    src.backup(dst)
                src.close()
                dst.close()
                log_audit_action("DATABASE_RESTORE", client_ip, "Database restored from backup", actor=actor_name)
                self.send_response_json(200, {"success": True, "message": "Database restored successfully"})
            except Exception as e:
                self.send_error_json(500, f"Restore failed: {e}")
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found. Use /block, /unblock, /config, /backup, or /restore")

def run_dashboard_server():
    global httpd_server
    try:
        bind_ip = DASHBOARD_BIND_IP
        if bind_ip in ('0.0.0.0', '::') or not bind_ip:
            print("⚠️ SECURITY WARNING: Dashboard is binding to 0.0.0.0/public interface. This exposes the API directly to the internet!")
        
        server_address = (bind_ip, 8088)
        # Use ThreadingHTTPServer for concurrent REST connections (Phase 3 Concurrency Upgrade)
        httpd_server = ThreadingHTTPServer(server_address, DashboardHandler)
        
        # HTTPS Configuration Support
        if SSL_CERT_PATH and SSL_KEY_PATH:
            if os.path.exists(SSL_CERT_PATH) and os.path.exists(SSL_KEY_PATH):
                try:
                    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                    context.load_cert_chain(certfile=SSL_CERT_PATH, keyfile=SSL_KEY_PATH)
                    httpd_server.socket = context.wrap_socket(httpd_server.socket, server_side=True)
                    print(f"Dashboard HTTPS API running on {bind_ip}:8088...")
                except Exception as ssl_err:
                    print(f"⚠️ SSL Context load failed: {ssl_err}. Falling back to unencrypted HTTP.")
            else:
                print("⚠️ SSL_CERT_PATH or SSL_KEY_PATH configured but files do not exist. Falling back to unencrypted HTTP.")
        else:
            print(f"Dashboard HTTP API running on {bind_ip}:8088...")
            
        httpd_server.serve_forever()
    except Exception as e:
        if not shutdown_event.is_set():
            print(f"Error starting dashboard server: {e}")

# ----------------- Graceful Shutdown Handling -----------------

def handle_shutdown_signal(signum, frame):
    global httpd_server
    print(f"\n[SYSTEM] Shutdown signal {signum} received. Initiating graceful shutdown...")
    shutdown_event.set()

    if httpd_server:
        print("[SYSTEM] Stopping Dashboard HTTP Server...")
        threading.Thread(target=httpd_server.shutdown, daemon=True).start()

    print("[SYSTEM] Stopping Database writer background thread...")
    db_write_queue.put(None)

# ----------------- Integrated Unit Tests Switch -----------------

def run_unit_tests():
    print("=== STARTING SECURITY MONITOR SELF-TESTS ===")
    
    # 1. Test LRU Cache
    cache = LRUCache(maxsize=3)
    cache.set('a', 1)
    cache.set('b', 2)
    cache.set('c', 3)
    cache.set('d', 4)  # should evict 'a'
    assert cache.get('a') is None, "LRU failed to evict 'a'"
    assert cache.get('b') == 2, "LRU evicted wrong key"
    cache.get('b')  # touch 'b'
    cache.set('e', 5)  # should evict 'c' because 'b' was touched
    assert cache.get('c') is None, "LRU failed to evict least recently used 'c'"
    print("[TEST] LRU Cache tests passed.")

    # 2. Test Decoders
    assert recursive_url_decode("%252527") == "'", "Recursive URL decoding failed"
    assert attempt_base64_decode("dW5pb24gc2VsZWN0") == "union select", "Base64 decoding failed"
    print("[TEST] URL & Base64 Decoder tests passed.")

    # 3. Test Regex Threat Scores
    sqli_text = "select * from users where id = 1"
    score, matches = calculate_threat_score(sqli_text, SQLI_SCORING)
    assert score >= 80, f"SQLi regex failed to detect classic pattern (score: {score})"
    
    xss_text = "<script>alert(1)</script>"
    score, matches = calculate_threat_score(xss_text, XSS_SCORING)
    assert score >= 80, f"XSS regex failed to detect script block (score: {score})"
    
    safe_text = "Select all fields from the report or update your profile."
    score, matches = calculate_threat_score(safe_text, SQLI_SCORING)
    assert score < 70, f"False positive: normal text triggered SQLi score: {score}"
    
    safe_text_rce = "run=true&cmd=test"
    assert not RCE_PATTERN.search(safe_text_rce), "False positive: RCE matched run=true&cmd=test"
    
    malicious_rce = "1;whoami"
    assert RCE_PATTERN.search(malicious_rce), "Failed to detect simple command injection"
    
    print("[TEST] Regex scoring and optimization tests passed.")
    
    # 4. Test Shannon Entropy
    assert calculate_entropy("aaaaa") == 0.0, "Entropy of repeating string should be 0"
    ent_rand = calculate_entropy("abcdefghijklmnopqrstuvwxyz")
    assert ent_rand > 4.0, "Entropy of random characters should be high"
    print("[TEST] Entropy calculations passed.")
    
    print("=== ALL SELF-TESTS COMPLETED SUCCESSFULLY ===")
    sys.exit(0)

# ----------------- Service Main Entry Point -----------------

if __name__ == '__main__':
    if '--test' in sys.argv:
        run_unit_tests()

    init_db()
    cfg = load_config()
    
    if not DASHBOARD_API_KEY:
        DASHBOARD_API_KEY = secrets.token_hex(16)
        print(f"⚠️ DASHBOARD_API_KEY not configured. Auto-generated secure token: {DASHBOARD_API_KEY}")
        save_api_key_to_config(DASHBOARD_API_KEY)
    else:
        print("Secure Dashboard API Key configured.")
        
    signal.signal(signal.SIGINT, handle_shutdown_signal)
    signal.signal(signal.SIGTERM, handle_shutdown_signal)
        
    t_db = threading.Thread(target=db_writer_worker, daemon=True)
    t_db.start()
        
    t_unban = threading.Thread(target=unban_worker, daemon=True)
    t_unban.start()
    
    t_alert = threading.Thread(target=alert_sender_worker, daemon=True)
    t_alert.start()
    
    t_dash = threading.Thread(target=run_dashboard_server, daemon=True)
    t_dash.start()
    
    tail_log_file(cfg['LOG_FILE_PATH'], cfg)
