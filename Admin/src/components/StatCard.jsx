/**
 * Stat Card Component
 * Displays a metric with icon and subtitle
 */

import { Paper, Box, Typography } from '@mui/material';

export default function StatCard({ title, value, icon, color, subtitle }) {
  return (
    <Paper sx={{ p: 3, height: '100%' }}>
      <Box display="flex" alignItems="center" mb={2}>
        <Box
          sx={{
            backgroundColor: color,
            color: 'white',
            borderRadius: 2,
            p: 1,
            mr: 2,
            display: 'flex',
            alignItems: 'center'
          }}
        >
          {icon}
        </Box>
        <Typography variant="subtitle2" color="text.secondary">
          {title}
        </Typography>
      </Box>
      <Typography variant="h4" fontWeight="bold">
        {value}
      </Typography>
      {subtitle && (
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
          {subtitle}
        </Typography>
      )}
    </Paper>
  );
}
