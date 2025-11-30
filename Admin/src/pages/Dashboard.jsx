/**
 * Main Dashboard Page
 * Displays platform statistics and key metrics
 * PERFORMANCE: Memoized components and smooth transitions
 */

import { useState, useEffect, memo, useCallback } from 'react';
import {
  Box,
  Grid,
  Paper,
  Typography,
  CircularProgress,
  Alert,
  Button,
  Fade,
  Grow,
  Skeleton
} from '@mui/material';
import {
  People,
  TrendingUp,
  AttachMoney,
  Warning,
  Logout
} from '@mui/icons-material';
import { signOut } from 'firebase/auth';
import { auth } from '../services/firebase';
import { getStats } from '../services/api';
import StatCard from '../components/StatCard';

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // PERFORMANCE: Memoized logout handler - must be before any conditional returns
  const handleLogout = useCallback(async () => {
    try {
      await signOut(auth);
    } catch (error) {
      console.error('Logout error:', error);
    }
  }, []);

  const loadStats = useCallback(async () => {
    try {
      setError(null);
      const data = await getStats();
      setStats(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadStats();

    // Refresh every 5 minutes (matches cache TTL)
    const interval = setInterval(loadStats, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [loadStats]);

  // PERFORMANCE: Show skeleton loaders instead of spinner for better perceived performance
  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
          <Skeleton variant="text" width={200} height={40} />
          <Skeleton variant="rounded" width={100} height={36} />
        </Box>
        <Grid container spacing={3}>
          {[1, 2, 3, 4].map((i) => (
            <Grid item xs={12} md={3} key={i}>
              <Fade in timeout={100 * i}>
                <Box>
                  <StatCardSkeleton />
                </Box>
              </Fade>
            </Grid>
          ))}
          <Grid item xs={12} md={6}>
            <Skeleton variant="rounded" height={200} />
          </Grid>
          <Grid item xs={12} md={6}>
            <Skeleton variant="rounded" height={200} />
          </Grid>
        </Grid>
      </Box>
    );
  }

  if (error) {
    return <Alert severity="error">{error}</Alert>;
  }

  return (
    <Fade in timeout={300}>
      <Box sx={{ p: 3 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
          <Typography variant="h4">
            Platform Overview
          </Typography>
          <Button
            variant="outlined"
            startIcon={<Logout />}
            onClick={handleLogout}
            sx={{
              transition: 'transform 0.15s ease, box-shadow 0.15s ease',
              '&:hover': {
                transform: 'translateY(-1px)',
              },
            }}
          >
            Logout
          </Button>
        </Box>

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
    </Fade>
  );
}

// PERFORMANCE: Memoized MetricRow to prevent unnecessary re-renders
const MetricRow = memo(function MetricRow({ label, value, color = "text.primary" }) {
  return (
    <Fade in timeout={200}>
      <Box
        display="flex"
        justifyContent="space-between"
        mb={1}
        sx={{
          transition: 'background-color 0.15s ease',
          borderRadius: 1,
          px: 0.5,
          mx: -0.5,
          '&:hover': {
            backgroundColor: 'action.hover',
          },
        }}
      >
        <Typography variant="body2" color="text.secondary">
          {label}
        </Typography>
        <Typography
          variant="body1"
          fontWeight="medium"
          color={color}
          sx={{ transition: 'color 0.2s ease' }}
        >
          {value}
        </Typography>
      </Box>
    </Fade>
  );
});

// Skeleton loader for stat cards during loading
function StatCardSkeleton() {
  return (
    <Paper sx={{ p: 3, height: '100%' }}>
      <Box display="flex" alignItems="center" mb={2}>
        <Skeleton variant="rounded" width={40} height={40} sx={{ mr: 2 }} />
        <Skeleton variant="text" width={80} />
      </Box>
      <Skeleton variant="text" width={120} height={40} />
      <Skeleton variant="text" width={100} sx={{ mt: 1 }} />
    </Paper>
  );
}
