const connectDB = require('./config/db');
const config = require('./config');
const app = require('./app');

const start = async () => {
  try {
    await connectDB();
    const server = app.listen(config.port, () => {
      console.log(`MCQ API running on http://localhost:${config.port} (${config.nodeEnv})`);
    });

    process.on('SIGTERM', () => {
      server.close(() => process.exit(0));
    });
    process.on('unhandledRejection', (err) => {
      console.error('UNHANDLED REJECTION:', err);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
};

start();
