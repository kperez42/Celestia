/**
 * API Service
 * Handles all API calls to Cloud Functions backend
 */

import axios from 'axios';
import { auth } from './firebase';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5001/celestia-dev/us-central1';

// Create axios instance
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Request interceptor - add auth token
api.interceptors.request.use(
  async (config) => {
    const user = auth.currentUser;
    if (user) {
      const token = await user.getIdToken();
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor - handle errors
api.interceptors.response.use(
  (response) => response.data,
  (error) => {
    if (error.response) {
      // Server responded with error
      const message = error.response.data?.error || error.response.statusText;
      console.error('API Error:', message);

      if (error.response.status === 403) {
        // Unauthorized - redirect to login
        window.location.href = '/login';
      }

      if (error.response.status === 429) {
        // Rate limited
        const retryAfter = error.response.data?.retryAfter || 60;
        throw new Error(`Rate limit exceeded. Please try again in ${retryAfter} seconds.`);
      }

      throw new Error(message);
    } else if (error.request) {
      // Request made but no response
      console.error('Network Error:', error.message);
      throw new Error('Network error - please check your connection');
    } else {
      // Something else happened
      console.error('Error:', error.message);
      throw error;
    }
  }
);

// ============================================================================
// ADMIN DASHBOARD APIs
// ============================================================================

export const getStats = () => api.get('/admin/stats');

export const getFlaggedContent = (params = {}) =>
  api.get('/admin/flagged-content', { params });

export const moderateContent = (contentId, action, reason) =>
  api.post('/admin/moderate-content', { contentId, action, reason });

export const getSubscriptionAnalytics = (period = 30) =>
  api.get('/admin/subscription-analytics', { params: { period } });

export const getFraudDashboard = () => api.get('/admin/fraud-dashboard');

export const getRefundTracking = (params = {}) =>
  api.get('/admin/refund-tracking', { params });

export const reviewFlaggedTransaction = (transactionId, decision, adminNote) =>
  api.post('/admin/review-transaction', { transactionId, decision, adminNote });

// ============================================================================
// NEW ENHANCED APIs
// ============================================================================

export const bulkUserOperation = (operation, userIds, options = {}) =>
  api.post('/admin/bulk-operation', { operation, userIds, options });

export const getUserTimeline = (userId, limit = 100) =>
  api.get(`/admin/user-timeline/${userId}`, { params: { limit } });

export const getFraudPatterns = (period = 30) =>
  api.get('/admin/fraud-patterns', { params: { period } });

export const getAdminAuditLogs = (params = {}) =>
  api.get('/admin/audit-logs', { params });

export const clearCache = (pattern = null) =>
  api.post('/admin/clear-cache', { pattern });

// ============================================================================
// MODERATION QUEUE APIs
// ============================================================================

export const getModerationQueue = (params = {}) =>
  api.get('/admin/moderation-queue', { params });

export const addToModerationQueue = (item) =>
  api.post('/admin/moderation-queue', item);

export const assignQueueItem = (itemId, moderatorId) =>
  api.post(`/admin/moderation-queue/${itemId}/assign`, { moderatorId });

export const autoAssignQueueItems = () =>
  api.post('/admin/moderation-queue/auto-assign');

export const completeModerationItem = (itemId, decision, moderatorNote) =>
  api.post(`/admin/moderation-queue/${itemId}/complete`, { decision, moderatorNote });

export const getQueueStats = () =>
  api.get('/admin/moderation-queue/stats');

export const escalateStaleItems = () =>
  api.post('/admin/moderation-queue/escalate');

export default api;
