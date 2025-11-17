/**
 * Main Dashboard Page
 * Displays platform statistics and key metrics
 */

import { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Paper,
  Typography,
  CircularProgress,
  Alert
} from '@mui/material';
import {
  People,
  TrendingUp,
  AttachMoney,
  Warning
} from '@mui/icons-material';
import { getStats } from '../services/api';
import StatCard from '../components/StatCard';

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadStats();

    // Refresh every 5 minutes (matches cache TTL)
    const interval = setInterval(loadStats, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  const loadStats = async () => {
    try {
      setError(null);
      const data = await getStats();
      setStats(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="60vh">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return <Alert severity="error">{error}</Alert>;
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Platform Overview
      </Typography>

      <Grid container spacing={3}>
        {/* User Stats */}
        <Grid item xs={12} md={3}>
          <StatCard
            title="Total Users"
            value={stats.users.total.toLocaleString()}
            icon={<People />}
            color="#1976d2"
            subtitle={`${stats.users.active.toLocaleString()} active (24h)`}
          />
        </Grid>

        <Grid item xs={12} md={3}>
          <StatCard
            title="Premium Users"
            value={stats.users.premium.toLocaleString()}
            icon={<TrendingUp />}
            color="#9c27b0"
            subtitle={`${((stats.users.premium / stats.users.total) * 100).toFixed(1)}% conversion`}
          />
        </Grid>

        <Grid item xs={12} md={3}>
          <StatCard
            title="Revenue (30d)"
            value={`$${stats.revenue.last30Days.toLocaleString()}`}
            icon={<AttachMoney />}
            color="#2e7d32"
            subtitle={`${stats.revenue.totalPurchases} purchases`}
          />
        </Grid>

        <Grid item xs={12} md={3}>
          <StatCard
            title="Pending Reviews"
            value={stats.moderation.pendingReviews}
            icon={<Warning />}
            color="#ed6c02"
            subtitle={`${stats.security.pendingFraudReviews} fraud alerts`}
          />
        </Grid>

        {/* Engagement Metrics */}
        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Engagement Metrics
            </Typography>
            <Box sx={{ mt: 2 }}>
              <MetricRow
                label="Total Matches"
                value={stats.engagement.totalMatches.toLocaleString()}
              />
              <MetricRow
                label="Match Rate"
                value={`${stats.engagement.matchRate} per user`}
              />
              <MetricRow
                label="Messages (24h)"
                value={stats.engagement.messagesLast24h.toLocaleString()}
              />
              <MetricRow
                label="Avg Messages/Match"
                value={stats.engagement.averageMessagesPerMatch}
              />
            </Box>
          </Paper>
        </Grid>

        {/* Security Metrics */}
        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Security & Moderation
            </Typography>
            <Box sx={{ mt: 2 }}>
              <MetricRow
                label="Fraud Attempts"
                value={stats.security.fraudAttempts}
                color="error"
              />
              <MetricRow
                label="High-Risk Transactions"
                value={stats.security.highRiskTransactions}
                color="warning"
              />
              <MetricRow
                label="Suspended Users"
                value={stats.users.suspended}
                color="error"
              />
              <MetricRow
                label="Pending Warnings"
                value={stats.moderation.pendingWarnings}
                color="warning"
              />
            </Box>
          </Paper>
        </Grid>

        {/* Revenue Breakdown */}
        <Grid item xs={12}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Revenue Breakdown (Last 30 Days)
            </Typography>
            <Grid container spacing={2} sx={{ mt: 1 }}>
              <Grid item xs={12} md={3}>
                <MetricRow
                  label="Subscriptions"
                  value={`$${stats.revenue.subscriptions.toLocaleString()}`}
                />
              </Grid>
              <Grid item xs={12} md={3}>
                <MetricRow
                  label="Consumables"
                  value={`$${stats.revenue.consumables.toLocaleString()}`}
                />
              </Grid>
              <Grid item xs={12} md={3}>
                <MetricRow
                  label="Refunded"
                  value={`$${stats.revenue.refundedRevenue.toLocaleString()}`}
                  color="error"
                />
              </Grid>
              <Grid item xs={12} md={3}>
                <MetricRow
                  label="Refund Rate"
                  value={`${stats.revenue.refundRate}%`}
                  color={stats.revenue.refundRate > 5 ? "error" : "success"}
                />
              </Grid>
            </Grid>
          </Paper>
        </Grid>
      </Grid>
    </Box>
  );
}

// Helper component for metric rows
function MetricRow({ label, value, color = "text.primary" }) {
  return (
    <Box display="flex" justifyContent="space-between" mb={1}>
      <Typography variant="body2" color="text.secondary">
        {label}
      </Typography>
      <Typography variant="body1" fontWeight="medium" color={color}>
        {value}
      </Typography>
    </Box>
  );
}
