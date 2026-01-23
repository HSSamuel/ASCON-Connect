import axios from "axios";

// 1. Create the Axios Instance
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || "https://ascon-st50.onrender.com",
});

// 2. Request Interceptor: Auto-attach Token
api.interceptors.request.use(
  (config) => {
    // Check both common storage keys just in case
    const token =
      localStorage.getItem("auth_token") || localStorage.getItem("token");

    if (token) {
      config.headers["auth-token"] = token;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  },
);

// 3. Response Interceptor: Handle 401 (Unauthorized) globally
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      // Token expired or invalid - optional: redirect to login
      console.warn("Session expired or invalid token.");
      // window.location.href = "/"; // Uncomment to auto-logout
    }
    return Promise.reject(error);
  },
);

export default api;
