// Direct GHIN API test — bypass the npm package due to schema issues

const FIREBASE_SESSION_URL = "https://firebaseinstallations.googleapis.com/v1/projects/ghin-mobile-app/installations";
const GOOGLE_API_KEY = "AIzaSyBxgTOAWxiud0HuaE5tN-5NTlzFnrtyz-I";
const GHIN_API = "https://api2.ghin.com/api/v1";

const SESSION_DEFAULTS = {
  appId: "1:884417644529:web:47fb315bc6c70242f72650",
  authVersion: "FIS_v2",
  fid: "fg6JfS0U01YmrelthLX9Iz",
  sdkVersion: "w:0.5.7",
};

async function getFirebaseToken() {
  const res = await fetch(`${FIREBASE_SESSION_URL}?key=${GOOGLE_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(SESSION_DEFAULTS),
  });
  const data = await res.json();
  return data.authToken.token;
}

async function ghinLogin(firebaseToken) {
  const res = await fetch(`${GHIN_API}/golfer_login.json`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${firebaseToken}`,
    },
    body: JSON.stringify({
      user: {
        email_or_ghin: "bknox123@gmail.com",
        password: "PJK6dab*krc9gqc-yze",
        remember_me: true,
      },
      token: firebaseToken,
    }),
  });
  const data = await res.json();
  console.log("   Login response:", JSON.stringify(data, null, 2).slice(0, 500));
  return data.golfer_user?.golfer_user_token || data.token;
}

async function main() {
  console.log("1. Getting Firebase token...");
  const fbToken = await getFirebaseToken();
  console.log("   Got Firebase token");

  console.log("2. Logging into GHIN...");
  const ghinToken = await ghinLogin(fbToken);
  console.log("   Got GHIN token");

  // Look up golfer
  console.log("\n3. Looking up golfer 13359198...");
  const golferRes = await fetch(
    `${GHIN_API}/golfers.json?golfer_id=13359198&from_ghin=true&per_page=1`,
    { headers: { Authorization: `Bearer ${ghinToken}` } }
  );
  const golferData = await golferRes.json();
  const golfer = golferData.golfers?.[0];
  if (golfer) {
    console.log(`   Name: ${golfer.first_name} ${golfer.last_name}`);
    console.log(`   Handicap Index: ${golfer.handicap_index}`);
    console.log(`   Club: ${golfer.club_name}`);
    console.log(`   Status: ${golfer.status}`);
  }

  // Get scores
  console.log("\n4. Getting recent scores...");
  const scoresRes = await fetch(
    `${GHIN_API}/scores.json?golfer_id=13359198&limit=10&page=1`,
    { headers: { Authorization: `Bearer ${ghinToken}` } }
  );
  const scoresData = await scoresRes.json();
  const scores = scoresData.scores || [];
  console.log(`   Found ${scores.length} scores`);
  scores.slice(0, 5).forEach((s) => {
    console.log(
      `   ${s.played_at} | ${s.course_name} | Gross: ${s.adjusted_gross_score} | Diff: ${s.differential} | Rating: ${s.course_rating} | Slope: ${s.slope_rating}`
    );
  });
}

main().catch((e) => console.error("Error:", e));
