import { supabaseAdmin } from '../services/supabase.js';
import { unauthorized } from '../utils/httpError.js';

export const authMiddleware = async (req, _res, next) => {
  try {
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;

    if (!token) {
      throw unauthorized('Missing bearer token');
    }

    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !data?.user) {
      throw unauthorized('Invalid or expired Supabase JWT');
    }

    req.user = {
      id: data.user.id,
      email: data.user.email ?? '',
      token
    };

    next();
  } catch (error) {
    next(error);
  }
};
