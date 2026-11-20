/**
 * storeHoursHelper.js
 * Comprehensive utility to check if a store is currently open or closed
 * based on weekly schedule or opening hours string, respecting Egypt timezone.
 */

const to12h = (timeStr) => {
  if (!timeStr || typeof timeStr !== 'string') return '';
  const parts = timeStr.trim().split(':');
  if (parts.length < 2) return timeStr;
  let h = parseInt(parts[0], 10);
  const m = parts[1].padStart(2, '0');
  if (isNaN(h)) return timeStr;
  const period = h >= 12 ? 'م' : 'ص';
  h = h % 12;
  if (h === 0) h = 12;
  const hStr = h.toString().padStart(2, '0');
  return `${hStr}:${m} ${period}`;
};

function formatOpeningHoursSummary(hours) {
  if (!hours) return '10:00 ص - 02:00 ص';
  if (typeof hours === 'string') {
    try {
      hours = JSON.parse(hours);
    } catch (_) {
      return hours.trim();
    }
  }
  if (typeof hours !== 'object' || hours === null) return '10:00 ص - 02:00 ص';

  const days = ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  const openDays = [];
  for (const day of days) {
    const config = hours[day];
    if (config && !config.closed && config.open && config.close) {
      openDays.push(config);
    }
  }

  if (openDays.length === 0) return 'مغلق مؤقتاً';

  const first = openDays[0];
  if (first.open === '00:00' && (first.close === '23:59' || first.close === '00:00')) {
    return 'مفتوح 24 ساعة';
  }

  const openStr = to12h(first.open);
  const closeStr = to12h(first.close);
  return `${openStr} - ${closeStr}`;
}

const parseTimeStringToMinutes = (tStr) => {
  if (!tStr || typeof tStr !== 'string') return null;
  const raw = tStr.trim().toLowerCase();

  let isPM = raw.includes('م') || raw.includes('pm');
  let isAM = raw.includes('ص') || raw.includes('am');

  const clean = raw.replace(/[^\d:]/g, '');
  const parts = clean.split(':');
  if (parts.length === 0 || parts[0] === '') return null;

  let h = parseInt(parts[0], 10);
  let m = parts.length > 1 ? parseInt(parts[1], 10) : 0;
  if (isNaN(h)) return null;
  if (isNaN(m)) m = 0;

  if (isPM && h < 12) h += 12;
  if (isAM && h === 12) h = 0;

  return h * 60 + m;
};

/**
 * Checks whether a store is currently open.
 * @param {string|object} hoursInput JSON or string representation of opening hours
 * @param {number|boolean} manualIsOpen Database flag (isOpen column)
 * @param {Date} [referenceDate] Optional date (defaults to current Egypt time)
 * @returns {{ isOpen: boolean, reason: string, summary: string }}
 */
function checkStoreOperatingStatus(hoursInput, manualIsOpen = 1, referenceDate = new Date()) {
  const summary = formatOpeningHoursSummary(hoursInput);

  // 1. Manual override by admin/merchant
  if (manualIsOpen === 0 || manualIsOpen === false || manualIsOpen === '0') {
    return {
      isOpen: false,
      reason: 'المتجر مغلق يدوياً من الإدارة أو التاجر',
      summary,
    };
  }

  // 2. Extract current weekday, hour, minute in Egypt (Africa/Cairo)
  let weekday = '';
  let hour = 0;
  let minute = 0;

  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Africa/Cairo',
      weekday: 'long',
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
    }).formatToParts(referenceDate);

    for (const p of parts) {
      if (p.type === 'weekday') weekday = p.value.toLowerCase();
      if (p.type === 'hour') hour = parseInt(p.value, 10);
      if (p.type === 'minute') minute = parseInt(p.value, 10);
    }
  } catch (e) {
    // Fallback to local system time if timeZone not supported
    const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    weekday = dayNames[referenceDate.getDay()];
    hour = referenceDate.getHours();
    minute = referenceDate.getMinutes();
  }

  const curMinutes = hour * 60 + minute;
  const daysOfWeek = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const curDayIndex = daysOfWeek.indexOf(weekday);
  const prevDay = daysOfWeek[(curDayIndex + 6) % 7];

  let parsedHours = hoursInput;
  if (typeof parsedHours === 'string') {
    try {
      parsedHours = JSON.parse(parsedHours);
    } catch (_) {}
  }

  // Case A: Structured object with daily configurations
  if (typeof parsedHours === 'object' && parsedHours !== null && !Array.isArray(parsedHours)) {
    // Check if yesterday had an overnight shift that extends past midnight into today
    const prevConfig = parsedHours[prevDay];
    if (prevConfig && !prevConfig.closed && prevConfig.open && prevConfig.close) {
      const pOpen = parseTimeStringToMinutes(prevConfig.open);
      const pClose = parseTimeStringToMinutes(prevConfig.close);
      if (pOpen !== null && pClose !== null && pOpen > pClose) {
        if (curMinutes <= pClose) {
          return {
            isOpen: true,
            reason: 'مفتوح (فترة عمل مستمرة من الأمس)',
            summary,
          };
        }
      }
    }

    const todayConfig = parsedHours[weekday];
    if (!todayConfig) {
      return { isOpen: true, reason: 'مفتوح', summary };
    }

    if (todayConfig.closed) {
      return {
        isOpen: false,
        reason: 'المتجر مغلق اليوم (يوم عطلة)',
        summary,
      };
    }

    const tOpen = parseTimeStringToMinutes(todayConfig.open);
    const tClose = parseTimeStringToMinutes(todayConfig.close);

    if (tOpen === null || tClose === null) {
      return { isOpen: true, reason: 'مفتوح', summary };
    }

    // 24 hours open
    if (tOpen === 0 && (tClose >= 1439 || tClose === 0)) {
      return { isOpen: true, reason: 'مفتوح 24 ساعة', summary };
    }

    if (tOpen <= tClose) {
      const open = curMinutes >= tOpen && curMinutes <= tClose;
      return {
        isOpen: open,
        reason: open ? 'مفتوح الآن' : 'مغلق خارج مواعيد العمل',
        summary,
      };
    } else {
      // Overnight shift (e.g. 10:00 to 02:00)
      const open = curMinutes >= tOpen || curMinutes <= tClose;
      return {
        isOpen: open,
        reason: open ? 'مفتوح الآن' : 'مغلق خارج مواعيد العمل',
        summary,
      };
    }
  }

  // Case B: String summary (e.g., "10:00 ص - 02:00 ص" or "09:00 - 23:00")
  if (typeof hoursInput === 'string') {
    const rawStr = hoursInput.trim();
    if (rawStr.includes('24 ساعة')) {
      return { isOpen: true, reason: 'مفتوح 24 ساعة', summary };
    }
    if (rawStr.includes('مغلق مؤقتاً') || rawStr.includes('مغلق')) {
      return { isOpen: false, reason: 'مغلق مؤقتاً', summary };
    }

    if (rawStr.includes('-')) {
      const rangeParts = rawStr.split('-');
      if (rangeParts.length >= 2) {
        const startMin = parseTimeStringToMinutes(rangeParts[0]);
        const endMin = parseTimeStringToMinutes(rangeParts[1]);

        if (startMin !== null && endMin !== null) {
          if (startMin <= endMin) {
            const open = curMinutes >= startMin && curMinutes <= endMin;
            return {
              isOpen: open,
              reason: open ? 'مفتوح الآن' : 'مغلق خارج مواعيد العمل',
              summary,
            };
          } else {
            // Overnight shift
            const open = curMinutes >= startMin || curMinutes <= endMin;
            return {
              isOpen: open,
              reason: open ? 'مفتوح الآن' : 'مغلق خارج مواعيد العمل',
              summary,
            };
          }
        }
      }
    }
  }

  // Fallback default
  return { isOpen: true, reason: 'مفتوح', summary };
}

module.exports = {
  formatOpeningHoursSummary,
  checkStoreOperatingStatus,
  parseTimeStringToMinutes,
};
