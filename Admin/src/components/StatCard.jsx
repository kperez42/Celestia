/**
 * Stat Card Component
 * Displays a metric with icon and subtitle
 * PERFORMANCE: Memoized to prevent unnecessary re-renders
 */

import { memo, useState, useEffect } from 'react';
import { Paper, Box, Typography, Fade } from '@mui/material';

// Memoized StatCard for smooth performance
const StatCard = memo(function StatCard({ title, value, icon, color, subtitle }) {
  const [isVisible, setIsVisible] = useState(false);
  const [displayValue, setDisplayValue] = useState(value);

  // Smooth fade-in on mount
  useEffect(() => {
    setIsVisible(true);
  }, []);

  // Animate value changes
  useEffect(() => {
    setDisplayValue(value);
  }, [value]);

  return (
    <Fade in={isVisible} timeout={300}>
      <Paper
        sx={{
          p: 3,
          height: '100%',
          transition: 'transform 0.2s ease, box-shadow 0.2s ease',
          '&:hover': {
            transform: 'translateY(-2px)',
            boxShadow: 4,
          },
        }}
      >
        <Box display="flex" alignItems="center" mb={2}>
          <Box
            sx={{
              backgroundColor: color,
              color: 'white',
              borderRadius: 2,
              p: 1,
              mr: 2,
              display: 'flex',
              alignItems: 'center',
              transition: 'transform 0.2s ease',
              '&:hover': {
                transform: 'scale(1.05)',
              },
            }}
          >
            {icon}
          </Box>
          <Typography variant="subtitle2" color="text.secondary">
            {title}
          </Typography>
        </Box>
        <Typography
          variant="h4"
          fontWeight="bold"
          sx={{
            transition: 'opacity 0.15s ease',
          }}
        >
          {displayValue}
        </Typography>
        {subtitle && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            {subtitle}
          </Typography>
        )}
      </Paper>
    </Fade>
  );
});

export default StatCard;
