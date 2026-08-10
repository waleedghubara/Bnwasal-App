require('dotenv').config();
const nodemailer = require('nodemailer');

console.log("Host:", process.env.EMAIL_HOST);
console.log("Port:", process.env.EMAIL_PORT);
console.log("User:", process.env.EMAIL_USER);
console.log("Pass:", process.env.EMAIL_PASS);

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,
  port: parseInt(process.env.EMAIL_PORT, 10),
  secure: process.env.EMAIL_PORT === '465',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  },
  tls: {
    rejectUnauthorized: false
  }
});

transporter.verify((error, success) => {
  if (error) {
    console.error("Verification failed:", error.message);
  } else {
    console.log("Verification SUCCESSFUL!");
  }
});
