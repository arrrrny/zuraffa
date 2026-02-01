import React, { useEffect } from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  
  useEffect(() => {
    // Redirect to the static landing page
    window.location.href = `${siteConfig.baseUrl}landing.html`;
  }, [siteConfig.baseUrl]);

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      height: '100vh',
      fontSize: '20px',
    }}>
      <p>Redirecting to landing page...</p>
    </div>
  );
}
