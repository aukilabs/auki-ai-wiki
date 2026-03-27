import { useState, useEffect, type FormEvent } from "react";

interface DomainResult {
  id: string;
  name: string;
  organization_id: string;
  created_at: string;
  updated_at: string;
  access_token: string | null;
}

interface DomainsResponse {
  domains: DomainResult[];
}

async function getDdsToken(): Promise<string> {
  // Login to API
  const loginRes = await fetch("/auth/user/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: "test@test.com", password: "testtest" }),
  });
  if (!loginRes.ok) throw new Error(`Login failed: ${loginRes.status}`);
  const { access_token: userToken } = await loginRes.json();

  // Exchange for DDS token
  const ddsRes = await fetch("/auth/service/domains-access-token", {
    method: "POST",
    headers: { Authorization: `Bearer ${userToken}` },
  });
  if (!ddsRes.ok) throw new Error(`DDS token failed: ${ddsRes.status}`);
  const { access_token: ddsToken } = await ddsRes.json();
  return ddsToken;
}

export default function App() {
  const [mac, setMac] = useState("");
  const [results, setResults] = useState<DomainResult[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ddsToken, setDdsToken] = useState<string | null>(null);
  const [authError, setAuthError] = useState<string | null>(null);

  useEffect(() => {
    getDdsToken()
      .then(setDdsToken)
      .catch((err) => setAuthError(err.message));
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!ddsToken) return;
    setError(null);
    setResults(null);
    setLoading(true);

    try {
      const normalized = mac.toUpperCase().trim();
      const res = await fetch(
        `/api/v1/domains?mac_address=${encodeURIComponent(normalized)}`,
        {
          headers: { Authorization: `Bearer ${ddsToken}` },
        }
      );

      if (!res.ok) {
        const text = await res.text();
        throw new Error(`${res.status}: ${text}`);
      }

      const data: DomainsResponse = await res.json();
      setResults(data.domains);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  if (authError) {
    return (
      <div style={{ maxWidth: 600, margin: "40px auto", fontFamily: "system-ui" }}>
        <h1>MAC Address Lookup</h1>
        <div style={{ padding: 12, background: "#fee", border: "1px solid #c00", borderRadius: 4, color: "#900" }}>
          Auth failed: {authError}. Is the local cluster running?
        </div>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 600, margin: "40px auto", fontFamily: "system-ui" }}>
      <h1>MAC Address Lookup</h1>
      <p style={{ color: "#666" }}>
        Enter a MAC address to find which posemesh domains contain it.
      </p>

      <form onSubmit={handleSubmit} style={{ display: "flex", gap: 8 }}>
        <input
          type="text"
          value={mac}
          onChange={(e) => setMac(e.target.value)}
          placeholder="AA:BB:CC:DD:EE:FF"
          style={{
            flex: 1,
            padding: "8px 12px",
            fontSize: 16,
            fontFamily: "monospace",
            border: "1px solid #ccc",
            borderRadius: 4,
          }}
        />
        <button
          type="submit"
          disabled={loading || !mac.trim() || !ddsToken}
          style={{
            padding: "8px 20px",
            fontSize: 16,
            cursor: loading ? "wait" : "pointer",
          }}
        >
          {!ddsToken ? "Authenticating..." : loading ? "Looking up..." : "Look up"}
        </button>
      </form>

      {error && (
        <div
          style={{
            marginTop: 16,
            padding: 12,
            background: "#fee",
            border: "1px solid #c00",
            borderRadius: 4,
            color: "#900",
          }}
        >
          {error}
        </div>
      )}

      {results !== null && (
        <div style={{ marginTop: 24 }}>
          <h2>
            {results.length === 0
              ? "No domains found"
              : `${results.length} domain${results.length > 1 ? "s" : ""} found`}
          </h2>
          <ul style={{ listStyle: "none", padding: 0 }}>
            {results.map((r) => (
              <li
                key={r.id}
                style={{
                  padding: 12,
                  marginBottom: 8,
                  background: "#f5f5f5",
                  borderRadius: 4,
                  border: "1px solid #ddd",
                }}
              >
                <strong>{r.name}</strong>
                <br />
                <code style={{ fontSize: 13, color: "#666" }}>
                  {r.id}
                </code>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
