import NodeCache from 'node-cache';

export const matchScoreCache = new NodeCache({
  stdTTL: 60 * 60 * 24,
  checkperiod: 120
});

export const jobsQueryCache = new NodeCache({
  stdTTL: 60 * 60 * 2,
  checkperiod: 120
});

export const cvAnalysisCache = new NodeCache({
  stdTTL: 60 * 60 * 12,
  checkperiod: 120
});

export const chatHistoryCache = new NodeCache({
  stdTTL: 60 * 30,
  checkperiod: 120
});
