const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validatePhone = (phone) => {
  // Simple check for numbers, spaces, plus and dashes, between 8 and 15 digits
  const phoneRegex = /^[\d\s+\-]{8,20}$/;
  return phoneRegex.test(phone);
};

const validatePassword = (password) => {
  if (!password || typeof password !== 'string') {
    return 'كلمة المرور مطلوبة';
  }
  if (password.length < 8) {
    return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  }
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    return 'كلمة المرور يجب أن تحتوي على أحرف وأرقام';
  }
  return null;
};

const validateRegisterInput = (body) => {
  const { firstName, lastName, email, phone, password, role } = body;

  if (!firstName || firstName.trim().length === 0) {
    return 'First name is required';
  }
  if (!lastName || lastName.trim().length === 0) {
    return 'Last name is required';
  }
  // Email is now optional — only validate if provided
  if (email && email.trim().length > 0 && !validateEmail(email)) {
    return 'A valid email address is required if provided';
  }
  if (!phone || !validatePhone(phone)) {
    return 'A valid phone number is required';
  }
  const pwdError = validatePassword(password);
  if (pwdError) {
    return pwdError;
  }
  if (!role || !['merchant', 'captain'].includes(role)) {
    return 'Role must be either merchant or captain';
  }

  return null;
};

module.exports = {
  validateEmail,
  validatePhone,
  validatePassword,
  validateRegisterInput,
};
