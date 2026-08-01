require('dotenv').config();

module.exports = {
  port: process.env.PORT || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/mcq',
  jwtSecret: process.env.JWT_SECRET || 'dev_secret_change_me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  admin: {
    name: process.env.ADMIN_NAME || 'Admin Muallim',
    email: process.env.ADMIN_EMAIL || 'admin@muallimcarpets.com',
    password: process.env.ADMIN_PASSWORD || 'Admin@123',
  },
  managerPassword: process.env.MANAGER_PASSWORD || 'Manager@123',
};
