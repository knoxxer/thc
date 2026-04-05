const FIREBASE_SESSION_URL =
  "https://firebaseinstallations.googleapis.com/v1/projects/ghin-mobile-app/installations";
const GOOGLE_API_KEY = "AIzaSyBxgTOAWxiud0HuaE5tN-5NTlzFnrtyz-I";
const GHIN_API = "https://api2.ghin.com/api/v1";

const SESSION_DEFAULTS = {
  appId: "1:884417644529:web:47fb315bc6c70242f72650",
  authVersion: "FIS_v2",
  fid: "fg6JfS0U01YmrelthLX9Iz",
  sdkVersion: "w:0.5.7",
};

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getFirebaseToken(): Promise<string> {
  const res = await fetch(`${FIREBASE_SESSION_URL}?key=${GOOGLE_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(SESSION_DEFAULTS),
  });
  const data = await res.json();
  return data.authToken.token;
}

async function getGhinToken(): Promise<string> {
  // Return cached token if still valid (with 5min buffer)
  if (cachedToken && Date.now() < cachedToken.expiresAt - 300_000) {
    return cachedToken.token;
  }

  const fbToken = await getFirebaseToken();

  const res = await fetch(`${GHIN_API}/golfer_login.json`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${fbToken}`,
    },
    body: JSON.stringify({
      user: {
        email_or_ghin: process.env.GHIN_EMAIL,
        password: process.env.GHIN_PASSWORD,
        remember_me: true,
      },
      token: fbToken,
    }),
  });

  const data = await res.json();

  if (!data.golfer_user?.golfer_user_token) {
    throw new Error(`GHIN login failed: ${JSON.stringify(data.errors || data)}`);
  }

  const token = data.golfer_user.golfer_user_token;
  // GHIN tokens last ~12 hours
  cachedToken = { token, expiresAt: Date.now() + 12 * 60 * 60 * 1000 };
  return token;
}

async function ghinFetch(path: string): Promise<Record<string, unknown>> {
  const token = await getGhinToken();
  const res = await fetch(`${GHIN_API}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`GHIN API error ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

export interface GhinGolfer {
  ghin_number: number;
  first_name: string;
  last_name: string;
  handicap_index: number | string | null;
  club_name: string;
  status: string;
}

export interface GhinScore {
  id: number;
  played_at: string;
  course_name: string;
  tee_name: string;
  adjusted_gross_score: number;
  differential: number;
  course_rating: number;
  slope_rating: number;
  number_of_holes: number;
  score_type: string;
}

export async function lookupGolfer(ghinNumber: number): Promise<GhinGolfer | null> {
  const data = await ghinFetch(
    `/golfers.json?golfer_id=${ghinNumber}&from_ghin=true&per_page=1&page=1`
  );
  const golfers = (data as { golfers?: GhinGolfer[] }).golfers;
  return golfers?.[0] || null;
}

export async function getScores(
  ghinNumber: number,
  limit = 20
): Promise<GhinScore[]> {
  const data = await ghinFetch(
    `/scores.json?golfer_id=${ghinNumber}&per_page=${limit}&page=1`
  );
  return ((data as { scores?: GhinScore[] }).scores || []) as GhinScore[];
}
