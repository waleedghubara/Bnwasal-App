const { getPool } = require('../config/db');
const path = require('path');
const fs = require('fs');

// GET all settings
const getSettings = async (req, res, next) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query('SELECT `key`, `value` FROM app_settings');
    const settings = {};
    for (const row of rows) {
      settings[row.key] = row.value;
    }
    res.status(200).json({ status: 1, data: { settings } });
  } catch (error) {
    next(error);
  }
};

// UPDATE social media links
const updateSocialLinks = async (req, res, next) => {
  try {
    const pool = getPool();
    const { facebook, instagram, twitter, whatsapp, linkedin, youtube } = req.body;
    const entries = {
      social_facebook: facebook || '',
      social_instagram: instagram || '',
      social_twitter: twitter || '',
      social_whatsapp: whatsapp || '',
      social_linkedin: linkedin || '',
      social_youtube: youtube || '',
    };
    for (const [key, value] of Object.entries(entries)) {
      await pool.query(
        'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
        [key, value, value]
      );
    }
    res.status(200).json({ status: 1, message: '✅ تم حفظ روابط التواصل الاجتماعي' });
  } catch (error) {
    next(error);
  }
};

// UPLOAD Windows update file
const uploadUpdate = async (req, res, next) => {
  try {
    const pool = getPool();
    if (!req.file) {
      return res.status(400).json({ status: 0, message: 'الرجاء رفع ملف التحديث' });
    }
    const { version, required } = req.body;
    const filePath = req.file.path.replace(/\\/g, '/');
    const fileName = req.file.filename;

    await pool.query(
      'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
      ['update_version', version || '1.0.0', version || '1.0.0']
    );
    await pool.query(
      'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
      ['update_file', fileName, fileName]
    );
    await pool.query(
      'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
      ['update_required', required === '1' ? '1' : '0', required === '1' ? '1' : '0']
    );

    res.status(200).json({
      status: 1,
      message: '✅ تم رفع التحديث بنجاح',
      data: { fileName, path: filePath, version: version || '1.0.0' },
    });
  } catch (error) {
    next(error);
  }
};

// DOWNLOAD update file
const downloadUpdate = async (req, res, next) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query("SELECT `value` FROM app_settings WHERE `key` = 'update_file'");
    if (rows.length === 0 || !rows[0].value) {
      return res.status(404).json({ status: 0, message: 'لا يوجد تحديث متاح' });
    }
    const fileName = rows[0].value;
    const filePath = path.join(__dirname, '..', 'uploads', 'updates', fileName);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ status: 0, message: 'ملف التحديث غير موجود' });
    }
    res.download(filePath, fileName);
  } catch (error) {
    next(error);
  }
};

// CHECK update status (for client)
const checkUpdate = async (req, res, next) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query("SELECT `key`, `value` FROM app_settings WHERE `key` IN ('update_version', 'update_required', 'update_file')");
    const result = { version: '1.0.0', required: false, hasUpdate: false };
    for (const row of rows) {
      if (row.key === 'update_version') result.version = row.value;
      if (row.key === 'update_required') result.required = row.value === '1';
      if (row.key === 'update_file') result.hasUpdate = !!row.value;
    }
    res.status(200).json({ status: 1, data: result });
  } catch (error) {
    next(error);
  }
};

// TOGGLE maintenance mode
const toggleMaintenance = async (req, res, next) => {
  try {
    const pool = getPool();
    const { enabled, message } = req.body;
    await pool.query(
      'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
      ['maintenance_mode', enabled === '1' ? '1' : '0', enabled === '1' ? '1' : '0']
    );
    if (message) {
      await pool.query(
        'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
        ['maintenance_message', message, message]
      );
    }
    res.status(200).json({
      status: 1,
      message: enabled === '1' ? '🛠️ تم تفعيل وضع الصيانة' : '✅ تم إلغاء وضع الصيانة',
    });
  } catch (error) {
    next(error);
  }
};

// UPDATE generic setting key
const ALLOWED_SETTING_KEYS = new Set([
  'maintenance_mode',
  'maintenance_message',
  'fee_collection_mode',
  'social_facebook',
  'social_instagram',
  'social_twitter',
  'social_whatsapp',
  'social_linkedin',
  'social_youtube',
  'play_store_url',
  'app_store_url',
  'support_phone',
  'support_email',
  'update_version',
  'update_required',
  'update_file',
  'merchant_video_url',
  'captain_video_url',
  'mobile_update_version',
  'mobile_update_required',
  'enable_auto_assignment',
  'auto_assignment_timeout',
  'max_reassignment_attempts',
  'max_attempts_per_captain',
  'captain_acceptance_timeout_seconds',
  'allow_auto_assignment_after_reject',
  'allow_auto_assignment_after_timeout',
  'route_matching_rule',
]);

const updateSettingKey = async (req, res, next) => {
  try {
    const pool = getPool();
    const { key, value } = req.body;
    if (!key) {
      return res.status(400).json({ status: 0, message: 'مفتاح الإعداد مطلوب' });
    }
    if (!ALLOWED_SETTING_KEYS.has(key)) {
      return res.status(400).json({ status: 0, message: 'مفتاح الإعداد غير مسموح' });
    }
    await pool.query(
      'INSERT INTO app_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = ?',
      [key, value || '', value || '']
    );
    res.status(200).json({ status: 1, message: '✅ تم تحديث الإعداد بنجاح' });
  } catch (error) {
    next(error);
  }
};

const getConfig = async (req, res, next) => {
  try {
    const pool = getPool();
    const [rows] = await pool.query(
      "SELECT `key`, `value` FROM app_settings WHERE `key` IN (" +
      "'maintenance_mode', 'maintenance_message', 'social_facebook', " +
      "'social_instagram', 'social_twitter', 'social_whatsapp', 'social_linkedin', " +
      "'social_youtube', 'update_version', 'update_required', 'play_store_url', 'app_store_url', " +
      "'support_phone', 'support_email', 'fee_collection_mode', 'merchant_video_url', 'captain_video_url', " +
      "'mobile_update_version', 'mobile_update_required'" +
      ")"
    );
    const config = {
      maintenance_mode: '0',
      maintenance_message: 'التطبيق في وضع الصيانة حالياً. يرجى المحاولة لاحقاً.',
      social_facebook: '',
      social_instagram: '',
      social_twitter: '',
      social_whatsapp: '',
      social_linkedin: '',
      social_youtube: '',
      update_version: '1.0.0',
      update_required: false,
      play_store_url: 'https://play.google.com/store/apps/details?id=com.wedeliver.app',
      app_store_url: 'https://apps.apple.com/app/we-deliver/id1234567890',
      support_phone: '+966500000000',
      support_email: 'support@binwasal.com',
      fee_collection_mode: 'after_agreement',
      merchant_video_url: '',
      captain_video_url: '',
      mobile_update_version: '1.0.0',
      mobile_update_required: false,
      captain_acceptance_timeout_seconds: '60'
    };
    for (const row of rows) {
      if (row.key === 'maintenance_mode') config.maintenance_mode = row.value;
      if (row.key === 'maintenance_message') config.maintenance_message = row.value;
      if (row.key === 'social_facebook') config.social_facebook = row.value;
      if (row.key === 'social_instagram') config.social_instagram = row.value;
      if (row.key === 'social_twitter') config.social_twitter = row.value;
      if (row.key === 'social_whatsapp') config.social_whatsapp = row.value;
      if (row.key === 'social_linkedin') config.social_linkedin = row.value;
      if (row.key === 'social_youtube') config.social_youtube = row.value;
      if (row.key === 'update_version') config.update_version = row.value;
      if (row.key === 'update_required') config.update_required = row.value === '1';
      if (row.key === 'play_store_url') config.play_store_url = row.value;
      if (row.key === 'app_store_url') config.app_store_url = row.value;
      if (row.key === 'support_phone') config.support_phone = row.value;
      if (row.key === 'support_email') config.support_email = row.value;
      if (row.key === 'fee_collection_mode') config.fee_collection_mode = row.value;
      if (row.key === 'merchant_video_url') config.merchant_video_url = row.value;
      if (row.key === 'captain_video_url') config.captain_video_url = row.value;
      if (row.key === 'mobile_update_version') config.mobile_update_version = row.value;
      if (row.key === 'mobile_update_required') config.mobile_update_required = row.value === '1';
      if (row.key === 'captain_acceptance_timeout_seconds') config.captain_acceptance_timeout_seconds = row.value;
    }
    // Override the generic config parameters returned to the mobile app with the mobile-specific values
    config.update_version = config.mobile_update_version;
    config.update_required = config.mobile_update_required;
    res.status(200).json({ status: 1, data: config });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getSettings,
  updateSocialLinks,
  uploadUpdate,
  downloadUpdate,
  checkUpdate,
  toggleMaintenance,
  updateSettingKey,
  getConfig,
};
