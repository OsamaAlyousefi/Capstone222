import admin from 'firebase-admin';

import { config } from '../config.js';

let initialized = false;

const ensureInitialized = () => {
  if (initialized || !config.fcmServiceAccount) {
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert(config.fcmServiceAccount)
  });

  initialized = true;
};

export const isFcmConfigured = Boolean(config.fcmServiceAccount);

export const sendPushNotification = async (token, title, body, data = {}) => {
  if (!token || !isFcmConfigured) {
    return { skipped: true };
  }

  ensureInitialized();

  await admin.messaging().send({
    token,
    notification: {
      title,
      body
    },
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)])
    )
  });

  return { skipped: false };
};
