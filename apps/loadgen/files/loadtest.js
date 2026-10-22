// k6 load test for the frontend (PDF: "Create load generator ... in order to load
// the application"). Requests go to the real HTTPS URL on the internal ALB, and the
// certificate is verified against the lab CA (SSL_CERT_FILE).
//
// ramping-arrival-rate sends a set number of requests per second, however fast the
// app answers, so each stage maps to a pod count. STAGES comes from values.yaml.
import http from "k6/http";
import { check } from "k6";

export const options = {
  insecureSkipTLSVerify: false,
  scenarios: {
    page_loads: {
      executor: "ramping-arrival-rate",
      startRate: 0,
      timeUnit: "1s",
      preAllocatedVUs: 10,
      maxVUs: 50,
      stages: JSON.parse(__ENV.STAGES),
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1000"],
  },
};

export default function () {
  const res = http.get(__ENV.TARGET_URL);
  check(res, {
    "status is 200": (r) => r.status === 200,
    "page shows Hello Lab-Commit": (r) => r.body.includes("Hello Lab-Commit v"),
  });
}
