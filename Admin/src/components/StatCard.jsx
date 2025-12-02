/**
 * Stat Card Component
 * Professional metric card with clean design
 */

import { memo } from 'react';
import { Box, Typography } from '@mui/material';
import { TrendingUp, TrendingDown } from '@mui/icons-material';

const StatCard = memo(function StatCard({
  title,
  value,
  icon,
  subtitle,
  trend,
  trendDirection = 'up'
}) {
  return (
    <Box
      sx={{
        p: 3,
        height: '100%',
        backgroundColor: '#1e293b',
        borderRadius: 2,
        border: '1px solid #334155',
        transition: 'border-color 0.2s ease',
        '&:hover': {
          borderColor: '#475569',
        },
      }}
    >
      {/* Header with icon and title */}
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          mb: 2,
        }}
      >
        <Typography
          variant="body2"
          sx={{
            color: '#94a3b8',
            fontWeight: 500,
            fontSize: '0.8125rem',
            textTransform: 'uppercase',
            letterSpacing: '0.025em',
          }}
        >
          {title}
        </Typography>
        <Box
          sx={{
            color: '#64748b',
            display: 'flex',
            alignItems: 'center',
          }}
        >
          {icon}
        </Box>
      </Box>

      {/* Value */}
      <Typography
        variant="h4"
        sx={{
          fontWeight: 700,
          color: '#f1f5f9',
          fontSize: '1.75rem',
          letterSpacing: '-0.02em',
          mb: 1,
        }}
      >
        {value}
      </Typography>

      {/* Subtitle/Trend */}
      {(subtitle || trend) && (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          {trend && (
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: 0.25,
                color: trendDirection === 'up' ? '#22c55e' : '#ef4444',
                fontSize: '0.75rem',
                fontWeight: 600,
              }}
            >
              {trendDirection === 'up' ? (
                <TrendingUp sx={{ fontSize: 16 }} />
              ) : (
                <TrendingDown sx={{ fontSize: 16 }} />
              )}
              {trend}
            </Box>
          )}
          {subtitle && (
            <Typography
              variant="body2"
              sx={{
                color: '#64748b',
                fontSize: '0.8125rem',
              }}
            >
              {subtitle}
            </Typography>
          )}
        </Box>
      )}
    </Box>
  );
});

export default StatCard;
