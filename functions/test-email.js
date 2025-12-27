const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'shahlajahan1982@gmail.com',
    pass: 'hcpl ramg dqqn jyby'
  }
});

const mailOptions = {
  from: 'noreply@barrkymatches.firebaseapp.com',
  to: 'shahlajahan1982@gmail.com',
  subject: 'Test Email',
  text: 'This is a test email from your Firebase project!'
};

transporter.sendMail(mailOptions, (error, info) => {
  if (error) {
    console.error('Error:', error);
  } else {
    console.log('Email sent:', info.response);
  }
});