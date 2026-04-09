export const ok = (res, payload, statusCode = 200) => {
  return res.status(statusCode).json(payload);
};
