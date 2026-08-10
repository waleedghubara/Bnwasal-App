package com.example.we_deliver

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.provider.Settings
import android.hardware.Sensor
import android.hardware.SensorManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.InputStreamReader
import java.net.Socket
import java.security.MessageDigest
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.we_deliver/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and screen recording to secure sensitive user data
        // window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        // Perform strict native-side RASP audit before startup sequence
        performSecurityAudit()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkSecurityEnvironment") {
                val results = HashMap<String, Any>()
                results["isRooted"] = checkRoot()
                results["isEmulator"] = checkEmulator()
                results["isFridaDetected"] = checkFrida()
                results["isDebuggerConnected"] = Debug.isDebuggerConnected() || checkTracerPid()
                results["isUsbDebuggingEnabled"] = checkUsbDebugging()
                results["isSignatureValid"] = checkSignature()
                results["isIntegrityValid"] = checkIntegrity()
                results["isNativeDebug"] = isNativeDebug()
                
                // Properties for emulator troubleshooting
                results["buildModel"] = Build.MODEL ?: "unknown"
                results["buildManufacturer"] = Build.MANUFACTURER ?: "unknown"
                results["buildHardware"] = Build.HARDWARE ?: "unknown"
                results["buildFingerprint"] = Build.FINGERPRINT ?: "unknown"
                results["buildProduct"] = Build.PRODUCT ?: "unknown"
                results["buildBoard"] = Build.BOARD ?: "unknown"
                results["buildDevice"] = Build.DEVICE ?: "unknown"
                results["buildBrand"] = Build.BRAND ?: "unknown"
                
                result.success(results)
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Strictly audit security configurations.
     * Terminate Activity and JVM immediately in production if any compromise is detected.
     */
    private fun performSecurityAudit() {
        val isRooted = checkRoot()
        val isEmulator = checkEmulator()
        val isFrida = checkFrida()
        val isDebugger = Debug.isDebuggerConnected() || checkTracerPid()
        val isUsbDebug = checkUsbDebugging()
        val isSignatureValid = checkSignature()
        val isIntegrityValid = checkIntegrity()

        // Critical threats that require immediate native-side termination in production/release
        // Signature and Integrity checks are delegated to Flutter (SecurityGuard) to prevent sudden crashes
        val hasCriticalThreat = isFrida || isDebugger

        if (hasCriticalThreat) {
            // Bypass enforcement ONLY if compiled as debug AND signed with the allowed developer debug signature.
            val isDeveloperDebug = isNativeDebug() && isDeveloperSignature()

            if (!isDeveloperDebug) {
                if (isNativeDebug()) {
                    android.util.Log.e("SecurityGuard", "CRITICAL SECURITY THREAT DETECTED. TERMINATING JVM.")
                }
                // Terminate JVM and close all activities instantly
                finishAffinity()
                System.exit(0)
            } else {
                if (isNativeDebug()) {
                    android.util.Log.w("SecurityGuard", "Security check violation detected but bypassed in developer debug mode.")
                }
            }
        }
    }

    private fun isDeveloperSignature(): Boolean {
        try {
            val pm = context.packageManager
            val packageName = context.packageName
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }
            if (signatures == null || signatures.isEmpty()) return false
            
            val md = MessageDigest.getInstance("SHA-256")
            val publicKey = md.digest(signatures[0].toByteArray())
            val hexString = publicKey.joinToString("") { String.format("%02x", it) }
            
            return hexString == "3db6bf604e48e884f9a2bc7ed5c7da6904d599a5b3d2296f5c0d53f8f807e573" ||
                   hexString == "765426e6b92d3df278fc391d1d27db734d019195ff846cfcdaff3a4a182a94b5"
        } catch (e: Exception) {
            return false
        }
    }

    private fun checkSignature(): Boolean {
        try {
            val pm = context.packageManager
            val packageName = context.packageName
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }
            
            if (signatures == null || signatures.isEmpty()) {
                return false
            }
            
            val md = MessageDigest.getInstance("SHA-256")
            val publicKey = md.digest(signatures[0].toByteArray())
            val hexString = publicKey.joinToString("") { String.format("%02x", it) }
            
            if (isNativeDebug()) {
                android.util.Log.d("SecurityGuard", "App Signature SHA-256: $hexString")
            }
            
            // Expected signatures list (Debug + Release / Production)
            val allowedSignatures = setOf(
                "3db6bf604e48e884f9a2bc7ed5c7da6904d599a5b3d2296f5c0d53f8f807e573", // Debug Keystore
                "765426e6b92d3df278fc391d1d27db734d019195ff846cfcdaff3a4a182a94b5", // Developer Release Keystore (my-release-key.jks)
                "16c7a40b9be00c2834b6b28e678bf1e35a64387d853e4142750e927c34e0684f"  // Production Google Play App Signing
            )
            
            return allowedSignatures.contains(hexString)
        } catch (e: Exception) {
            return false
        }
    }

    private fun checkIntegrity(): Boolean {
        try {
            // 1. Verify package name
            if (context.packageName != "online.walidghubara.wedeliver") {
                return false
            }
            
            // 2. Check for dual app/cloning systems
            if (checkCloning()) {
                return false
            }
            
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun checkCloning(): Boolean {
        try {
            val filesPath = context.filesDir.absolutePath
            if (filesPath.contains("/999/") || 
                filesPath.contains("/parallel/") || 
                filesPath.contains("/dual/") ||
                filesPath.contains("/virtual/") ||
                filesPath.contains("com.lody.virtual") ||
                filesPath.contains("com.parallel.space") ||
                filesPath.contains("multipleaccounts")
            ) {
                return true
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }

    private fun isNativeDebug(): Boolean {
        return try {
            (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun checkRoot(): Boolean {
        // 1. Build tags check
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        // 2. Directory binary check (su / busybox)
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/usr/we-need-su/su",
            "/system/xbin/busybox"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }

        // 3. Proc mounts check (looking for Magisk / KernelSU mounts)
        if (checkMountsForRoot()) {
            return true
        }

        // 4. su execution test
        var process: Process? = null
        try {
            process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val inReader = BufferedReader(InputStreamReader(process.inputStream))
            if (inReader.readLine() != null) return true
        } catch (t: Throwable) {
            // ignore
        } finally {
            process?.destroy()
        }

        return false
    }

    private fun checkMountsForRoot(): Boolean {
        try {
            val reader = BufferedReader(FileReader("/proc/mounts"))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val lowerLine = line!!.lowercase(Locale.ROOT)
                if (lowerLine.contains("magisk") ||
                    lowerLine.contains("zygisk") ||
                    lowerLine.contains("kernelsu") ||
                    lowerLine.contains("apatch") ||
                    lowerLine.contains("overlay") && lowerLine.contains("su")
                ) {
                    reader.close()
                    return true
                }
            }
            reader.close()
        } catch (e: Exception) {
            // ignore
        }
        return false
    }

    private fun checkEmulator(): Boolean {
        val model = Build.MODEL ?: ""
        val manufacturer = Build.MANUFACTURER ?: ""
        val product = Build.PRODUCT ?: ""
        val hardware = Build.HARDWARE ?: ""
        val fingerprint = Build.FINGERPRINT ?: ""
        val board = Build.BOARD ?: ""
        val device = Build.DEVICE ?: ""
        val brand = Build.BRAND ?: ""

        // 1. Build properties check
        if (fingerprint.startsWith("generic")
            || fingerprint.startsWith("unknown")
            || model.contains("google_sdk")
            || model.contains("Emulator")
            || model.contains("Android SDK built for x86")
            || board == "QC_Reference_Phone"
            || manufacturer.contains("Genymotion")
            || Build.HOST.startsWith("Build")
            || (brand.startsWith("generic") && device.startsWith("generic"))
            || "google_sdk" == product
            || hardware.contains("goldfish")
            || hardware.contains("ranchu")
            || hardware.contains("vbox86")
            || hardware.lowercase(Locale.ROOT).contains("nox")
            || model.contains("VirtualBox")
            || model.lowercase(Locale.ROOT).contains("nox")
            || model.lowercase(Locale.ROOT).contains("ldplayer")
            || model.lowercase(Locale.ROOT).contains("bluestacks")
            || product.contains("vbox86")
            || product.lowercase(Locale.ROOT).contains("nox")
            || product.lowercase(Locale.ROOT).contains("bluestacks")
            || product.lowercase(Locale.ROOT).contains("ldplayer")
            || board.contains("vbox86")
            || board.lowercase(Locale.ROOT).contains("nox")
            || device.contains("vbox86")
            || device.lowercase(Locale.ROOT).contains("nox")
            || manufacturer.lowercase(Locale.ROOT).contains("bluestacks")
            || manufacturer.lowercase(Locale.ROOT).contains("nox")
            || manufacturer.contains("VirtualBox")
        ) {
            return true
        }

        // 2. Emulator-specific file systems check
        val emulatorPaths = arrayOf(
            "/system/bin/nox-prop",
            "/system/bin/nox",
            "/system/bin/noxd",
            "/system/lib/libnox.so",
            "/system/bin/ttVM_x86",
            "/system/bin/androVM-prop",
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "/system/bin/ldmount",
            "/system/bin/ldd",
            "/system/bin/ldplay",
            "/system/app/bluestacks.apk",
            "/system/lib/libtros.so"
        )
        for (path in emulatorPaths) {
            if (File(path).exists()) return true
        }

        // 3. Spoofed custom brand alignment check
        val brandLower = brand.lowercase(Locale.ROOT)
        val manufacturerLower = manufacturer.lowercase(Locale.ROOT)
        val fingerprintLower = fingerprint.lowercase(Locale.ROOT)
        if ((brandLower.contains("oppo") || manufacturerLower.contains("oppo")) &&
            (fingerprintLower.contains("samsung") || fingerprintLower.contains("gracelte") || fingerprintLower.contains("galaxy") || fingerprintLower.contains("google"))
        ) {
            return true
        }
        if ((brandLower.contains("samsung") || manufacturerLower.contains("samsung")) &&
            (fingerprintLower.contains("oppo") || fingerprintLower.contains("xiaomi") || fingerprintLower.contains("huawei") || fingerprintLower.contains("google"))
        ) {
            return true
        }

        // 4. Sensors heuristic check (emulators usually lack real hardware sensors)
        try {
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val sensors = sensorManager.getSensorList(Sensor.TYPE_ALL)
            if (sensors.size < 5) {
                return true
            }
        } catch (e: Exception) {
            // ignore
        }

        return false
    }

    private fun checkFrida(): Boolean {
        // 1. Proc maps check
        try {
            val reader = BufferedReader(FileReader("/proc/self/maps"))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val lowerLine = line!!.lowercase(Locale.ROOT)
                if (lowerLine.contains("frida") || lowerLine.contains("gadget") || lowerLine.contains("xposed") || lowerLine.contains("gum-js")) {
                    reader.close()
                    return true
                }
            }
            reader.close()
        } catch (e: Exception) {
            // ignore
        }

        // 2. Sockets check (checks default Frida port 27042 with a rapid 15ms timeout)
        if (checkFridaPort()) {
            return true
        }

        // 3. TracerPid tracing check
        if (checkTracerPid()) {
            return true
        }

        return false
    }

    private fun checkFridaPort(): Boolean {
        return try {
            val socket = Socket()
            socket.connect(java.net.InetSocketAddress("127.0.0.1", 27042), 15)
            socket.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun checkTracerPid(): Boolean {
        try {
            val statusFile = File("/proc/self/status")
            if (statusFile.exists()) {
                val reader = BufferedReader(FileReader(statusFile))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    if (line!!.startsWith("TracerPid:")) {
                        val tracerPid = line!!.substring(10).trim().toIntOrNull() ?: 0
                        if (tracerPid != 0) {
                            reader.close()
                            return true
                        }
                    }
                }
                reader.close()
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }

    private fun checkUsbDebugging(): Boolean {
        val globalAdb = Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0)
        val secureAdb = Settings.Secure.getInt(context.contentResolver, Settings.Secure.ADB_ENABLED, 0)
        if (globalAdb != 0 || secureAdb != 0) return true

        // Check if ADB running status is active
        try {
            val process = Runtime.getRuntime().exec("getprop init.svc.adbd")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val value = reader.readLine()
            if (value != null && value.trim().lowercase(Locale.ROOT) == "running") {
                return true
            }
        } catch (e: Exception) {
            // ignore
        }

        return false
    }
}
