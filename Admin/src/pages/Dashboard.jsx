/**
 * Main Dashboard Page
 * Professional admin dashboard with platform statistics
 */

import { useState, useEffect, memo, useCallback } from 'react';
import {
  Box,
  Grid,
  Typography,
  Alert,
  Skeleton,
  IconButton,
  Tooltip,
  Chip,
} from '@mui/material';
import {
  People,
  TrendingUp,
  AttachMoney,
  Warning,
  Refresh,
  Security,
  Message,
  Favorite,
} from '@mui/icons-material';
import { auth } from '../services/firebase';
import { getStats } from '../services/api';
import Layout from '../components/Layout';
import StatCard from '../components/StatCard';

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  const loadStats = useCallback(async (showRefreshing = false) => {
    try {
      if (showRefreshing) setRefreshing(true);
      setError(null);
      const data = await getStats();
      setStats(data);
      setLastUpdated(new Date());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    loadStats();
    // Refresh every 5 minutes (matches cache TTL)
    const interval = setInterval(() => loadStats(false), 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [loadStats]);

  const userEmail = auth.currentUser?.email;

  if (loading) {
    return (
      <Layout userEmail={userEmail}>
        <DashboardSkeleton />
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout userEmail={userEmail}>
        <Box sx={{ p: 4 }}>
          <Alert
            severity="error"
            sx={{
              backgroundColor: '#ef444420',
              color: '#fca5a5',
              border: '1px solid #ef444440',
            }}
          >
            {error}
          </Alert>
        </Box>
      </Layout>
    );
  }

  return (
    <Layout userEmail={userEmail}>
      <Box sx={{ p: 4 }}>
        {/* Header */}
        <Box
          sx={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            mb: 4,
          }}
        >
          <Box>
            <Typography
              variant="h4"
              sx={{
                fontWeight: 700,
                color: '#f1f5f9',
                mb: 0.5,
              }}
            >
              Dashboard
            </Typography>
            <Typography
              variant="body2"
              sx={{ color: '#64748b' }}
            >
              Platform overview and key metrics
            </Typography>
          </Box>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            {lastUpdated && (
              <Typography
                variant="caption"
                sx={{ color: '#64748b' }}
              >
                Updated {lastUpdated.toLocaleTimeString()}
              </Typography>
            )}
            <Tooltip title="Refresh data">
              <IconButton
                onClick={() => loadStats(true)}
                disabled={refreshing}
                size="small"
                sx={{
                  color: '#64748b',
                  '&:hover': {
                    color: '#f1f5f9',
                    backgroundColor: '#334155',
                  },
                }}
              >
                <Refresh
                  fontSize="small"
                  sx={{
                    animation: refreshing ? 'spin 1s linear infinite' : 'none',
                    '@keyframes spin': {
                      '0%': { transform: 'rotate(0deg)' },
                      '100%': { transform: 'rotate(360deg)' },
                    },
                  }}
                />
              </IconButton>
            </Tooltip>
          </Box>
        </Box>

        {/* Key Metrics */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} sm={6} lg={3}>
            <StatCard
              title="Total Users"
              value={stats.users.total.toLocaleString()}
              icon={<People fontSize="small" />}
              subtitle={`${stats.users.active.toLocaleString()} active (24h)`}
            />
          </Grid>
          <Grid item xs={12} sm={6} lg={3}>
            <StatCard
              title="Premium Users"
              value={stats.users.premium.toLocaleString()}
              icon={<TrendingUp fontSize="small" />}
              subtitle={`${((stats.users.premium / stats.users.total) * 100).toFixed(1)}% conversion`}
            />
          </Grid>
          <Grid item xs={12} sm={6} lg={3}>
            <StatCard
              title="Revenue (30d)"
              value={`$${stats.revenue.last30Days.toLocaleString()}`}
              icon={<AttachMoney fontSize="small" />}
              subtitle={`${stats.revenue.totalPurchases} purchases`}
            />
          </Grid>
          <Grid item xs={12} sm={6} lg={3}>
            <StatCard
              title="Pending Reviews"
              value={stats.moderation.pendingReviews}
              icon={<Warning fontSize="small" />}
              subtitle={`${stats.security.pendingFraudReviews} fraud alerts`}
            />
          </Grid>
        </Grid>

        {/* Two Column Section */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          {/* Engagement Metrics */}
          <Grid item xs={12} lg={6}>
            <Box
              sx={{
                p: 3,
                backgroundColor: '#1e293b',
                borderRadius: 2,
                border: '1px solid #334155',
                height: '100%',
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3 }}>
                <Favorite sx={{ color: '#64748b', fontSize: 20 }} />
                <Typography
                  variant="h6"
                  sx={{
                    fontWeight: 600,
                    color: '#f1f5f9',
                    fontSize: '1rem',
                  }}
                >
                  Engagement Metrics
                </Typography>
              </Box>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
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
            </Box>
          </Grid>

          {/* Security Metrics */}
          <Grid item xs={12} lg={6}>
            <Box
              sx={{
                p: 3,
                backgroundColor: '#1e293b',
                borderRadius: 2,
                border: '1px solid #334155',
                height: '100%',
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3 }}>
                <Security sx={{ color: '#64748b', fontSize: 20 }} />
                <Typography
                  variant="h6"
                  sx={{
                    fontWeight: 600,
                    color: '#f1f5f9',
                    fontSize: '1rem',
                  }}
                >
                  Security & Moderation
                </Typography>
              </Box>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <MetricRow
                  label="Fraud Attempts"
                  value={stats.security.fraudAttempts}
                  status="error"
                />
                <MetricRow
                  label="High-Risk Transactions"
                  value={stats.security.highRiskTransactions}
                  status="warning"
                />
                <MetricRow
                  label="Suspended Users"
                  value={stats.users.suspended}
                  status="error"
                />
                <MetricRow
                  label="Pending Warnings"
                  value={stats.moderation.pendingWarnings}
                  status="warning"
                />
              </Box>
            </Box>
          </Grid>
        </Grid>

        {/* Revenue Breakdown */}
        <Box
          sx={{
            p: 3,
            backgroundColor: '#1e293b',
            borderRadius: 2,
            border: '1px solid #334155',
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3 }}>
            <AttachMoney sx={{ color: '#64748b', fontSize: 20 }} />
            <Typography
              variant="h6"
              sx={{
                fontWeight: 600,
                color: '#f1f5f9',
                fontSize: '1rem',
              }}
            >
              Revenue Breakdown
            </Typography>
            <Chip
              label="Last 30 Days"
              size="small"
              sx={{
                backgroundColor: '#334155',
                color: '#94a3b8',
                fontSize: '0.6875rem',
                height: 22,
              }}
            />
          </Box>
          <Grid container spacing={3}>
            <Grid item xs={6} md={3}>
              <Box>
                <Typography
                  variant="caption"
                  sx={{
                    color: '#64748b',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                    fontSize: '0.6875rem',
                    fontWeight: 500,
                  }}
                >
                  Subscriptions
                </Typography>
                <Typography
                  variant="h5"
                  sx={{
                    fontWeight: 700,
                    color: '#f1f5f9',
                    mt: 0.5,
                  }}
                >
                  ${stats.revenue.subscriptions.toLocaleString()}
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={6} md={3}>
              <Box>
                <Typography
                  variant="caption"
                  sx={{
                    color: '#64748b',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                    fontSize: '0.6875rem',
                    fontWeight: 500,
                  }}
                >
                  Consumables
                </Typography>
                <Typography
                  variant="h5"
                  sx={{
                    fontWeight: 700,
                    color: '#f1f5f9',
                    mt: 0.5,
                  }}
                >
                  ${stats.revenue.consumables.toLocaleString()}
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={6} md={3}>
              <Box>
                <Typography
                  variant="caption"
                  sx={{
                    color: '#64748b',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                    fontSize: '0.6875rem',
                    fontWeight: 500,
                  }}
                >
                  Refunded
                </Typography>
                <Typography
                  variant="h5"
                  sx={{
                    fontWeight: 700,
                    color: '#ef4444',
                    mt: 0.5,
                  }}
                >
                  ${stats.revenue.refundedRevenue.toLocaleString()}
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={6} md={3}>
              <Box>
                <Typography
                  variant="caption"
                  sx={{
                    color: '#64748b',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                    fontSize: '0.6875rem',
                    fontWeight: 500,
                  }}
                >
                  Refund Rate
                </Typography>
                <Typography
                  variant="h5"
                  sx={{
                    fontWeight: 700,
                    color: stats.revenue.refundRate > 5 ? '#ef4444' : '#22c55e',
                    mt: 0.5,
                  }}
                >
                  {stats.revenue.refundRate}%
                </Typography>
              </Box>
            </Grid>
          </Grid>
        </Box>
      </Box>
    </Layout>
  );
}

// Metric Row Component
const MetricRow = memo(function MetricRow({ label, value, status }) {
  const getStatusColor = () => {
    switch (status) {
      case 'error':
        return '#ef4444';
      case 'warning':
        return '#f59e0b';
      case 'success':
        return '#22c55e';
      default:
        return '#f1f5f9';
    }
  };

  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        py: 1,
        px: 1.5,
        borderRadius: 1,
        backgroundColor: '#0f172a',
        transition: 'background-color 0.15s ease',
        '&:hover': {
          backgroundColor: '#1e293b80',
        },
      }}
    >
      <Typography
        variant="body2"
        sx={{
          color: '#94a3b8',
          fontSize: '0.875rem',
        }}
      >
        {label}
      </Typography>
      <Typography
        variant="body1"
        sx={{
          fontWeight: 600,
          color: getStatusColor(),
          fontSize: '0.9375rem',
        }}
      >
        {value}
      </Typography>
    </Box>
  );
});

// Skeleton loader for dashboard
function DashboardSkeleton() {
  return (
    <Box sx={{ p: 4 }}>
      {/* Header Skeleton */}
      <Box sx={{ mb: 4 }}>
        <Skeleton
          variant="text"
          width={150}
          height={40}
          sx={{ backgroundColor: '#334155' }}
        />
        <Skeleton
          variant="text"
          width={250}
          height={24}
          sx={{ backgroundColor: '#334155' }}
        />
      </Box>

      {/* Stats Cards Skeleton */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {[1, 2, 3, 4].map((i) => (
          <Grid item xs={12} sm={6} lg={3} key={i}>
            <Box
              sx={{
                p: 3,
                backgroundColor: '#1e293b',
                borderRadius: 2,
                border: '1px solid #334155',
              }}
            >
              <Skeleton
                variant="text"
                width={80}
                height={20}
                sx={{ backgroundColor: '#334155', mb: 2 }}
              />
              <Skeleton
                variant="text"
                width={100}
                height={36}
                sx={{ backgroundColor: '#334155' }}
              />
              <Skeleton
                variant="text"
                width={120}
                height={18}
                sx={{ backgroundColor: '#334155', mt: 1 }}
              />
            </Box>
          </Grid>
        ))}
      </Grid>

      {/* Content Skeleton */}
      <Grid container spacing={3}>
        <Grid item xs={12} lg={6}>
          <Skeleton
            variant="rounded"
            height={280}
            sx={{ backgroundColor: '#1e293b', borderRadius: 2 }}
          />
        </Grid>
        <Grid item xs={12} lg={6}>
          <Skeleton
            variant="rounded"
            height={280}
            sx={{ backgroundColor: '#1e293b', borderRadius: 2 }}
          />
        </Grid>
      </Grid>
    </Box>
  );
}
