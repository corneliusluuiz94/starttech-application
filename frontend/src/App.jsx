import { useEffect, useState } from "react";
import "./App.css";

function App() {
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/v1/health")
      .then((res) => res.json())
      .then((data) => {
        setHealth(data);
        setLoading(false);
      })
      .catch((err) => {
        setHealth({
          status: "error",
          error: err.message,
        });
        setLoading(false);
      });
  }, []);

  return (
    <div
      style={{
        maxWidth: "700px",
        margin: "40px auto",
        fontFamily: "Arial, sans-serif",
        padding: "20px",
      }}
    >
      <h1>StartTech DevOps Assessment</h1>

      <p>
        React Frontend hosted on Amazon S3 + CloudFront
      </p>

      <p>
        Golang Backend running on Amazon EKS
      </p>

      <hr />

      <h2>Backend Health</h2>

      {loading ? (
        <p>Checking backend...</p>
      ) : (
        <pre
          style={{
            background: "#f4f4f4",
            padding: "15px",
            borderRadius: "8px",
          }}
        >
          {JSON.stringify(health, null, 2)}
        </pre>
      )}
    </div>
  );
}

export default App;