import rateLimit from 'express-rate-limit';

const baseConfig = {
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: true,
    message: 'Too many requests. Please slow down.',
    code: 429
  }
};

export const globalLimiter = rateLimit({
  ...baseConfig,
  windowMs: 60 * 1000,
  max: 100
});

export const aiLimiter = rateLimit({
  ...baseConfig,
  windowMs: 60 * 1000,
  max: 15
});
