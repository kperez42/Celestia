/**
 * Admin Layout Component
 * Professional sidebar layout with navigation
 */

import { memo, useCallback } from 'react';
import {
  Box,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Divider,
  Avatar,
  IconButton,
  Tooltip,
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  People,
  Security,
  AttachMoney,
  Assessment,
  Logout,
  Settings,
} from '@mui/icons-material';
import { signOut } from 'firebase/auth';
import { auth } from '../services/firebase';

const DRAWER_WIDTH = 260;

const navigationItems = [
  { label: 'Dashboard', icon: DashboardIcon, path: '/', active: true },
  { label: 'Users', icon: People, path: '/users', disabled: true },
  { label: 'Moderation', icon: Security, path: '/moderation', disabled: true },
  { label: 'Revenue', icon: AttachMoney, path: '/revenue', disabled: true },
  { label: 'Analytics', icon: Assessment, path: '/analytics', disabled: true },
];

const Layout = memo(function Layout({ children, userEmail }) {
  const handleLogout = useCallback(async () => {
    try {
      await signOut(auth);
    } catch (error) {
      console.error('Logout error:', error);
    }
  }, []);

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      {/* Sidebar */}
      <Drawer
        variant="permanent"
        sx={{
          width: DRAWER_WIDTH,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: DRAWER_WIDTH,
            boxSizing: 'border-box',
            backgroundColor: '#0f172a',
            borderRight: '1px solid #1e293b',
          },
        }}
      >
        {/* Logo/Brand */}
        <Box sx={{ p: 3, pb: 2 }}>
          <Typography
            variant="h5"
            sx={{
              fontWeight: 700,
              color: '#f1f5f9',
              letterSpacing: '-0.02em',
            }}
          >
            Celestia
          </Typography>
          <Typography
            variant="caption"
            sx={{
              color: '#64748b',
              fontSize: '0.75rem',
              fontWeight: 500,
              letterSpacing: '0.05em',
              textTransform: 'uppercase',
            }}
          >
            Admin Console
          </Typography>
        </Box>

        <Divider sx={{ borderColor: '#1e293b', mx: 2 }} />

        {/* Navigation */}
        <List sx={{ px: 2, py: 2, flex: 1 }}>
          {navigationItems.map((item) => (
            <ListItem key={item.label} disablePadding sx={{ mb: 0.5 }}>
              <ListItemButton
                disabled={item.disabled}
                sx={{
                  borderRadius: 2,
                  py: 1.25,
                  px: 2,
                  backgroundColor: item.active ? '#1e293b' : 'transparent',
                  '&:hover': {
                    backgroundColor: item.active ? '#1e293b' : '#1e293b80',
                  },
                  '&.Mui-disabled': {
                    opacity: 0.4,
                  },
                }}
              >
                <ListItemIcon
                  sx={{
                    minWidth: 40,
                    color: item.active ? '#3b82f6' : '#64748b',
                  }}
                >
                  <item.icon fontSize="small" />
                </ListItemIcon>
                <ListItemText
                  primary={item.label}
                  primaryTypographyProps={{
                    fontSize: '0.875rem',
                    fontWeight: item.active ? 600 : 500,
                    color: item.active ? '#f1f5f9' : '#94a3b8',
                  }}
                />
              </ListItemButton>
            </ListItem>
          ))}
        </List>

        <Divider sx={{ borderColor: '#1e293b', mx: 2 }} />

        {/* User Section */}
        <Box sx={{ p: 2 }}>
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              gap: 1.5,
              p: 1.5,
              borderRadius: 2,
              backgroundColor: '#1e293b',
            }}
          >
            <Avatar
              sx={{
                width: 36,
                height: 36,
                backgroundColor: '#3b82f6',
                fontSize: '0.875rem',
                fontWeight: 600,
              }}
            >
              {userEmail?.charAt(0).toUpperCase() || 'A'}
            </Avatar>
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography
                variant="body2"
                sx={{
                  fontWeight: 600,
                  color: '#f1f5f9',
                  fontSize: '0.8125rem',
                }}
              >
                Admin
              </Typography>
              <Typography
                variant="caption"
                sx={{
                  color: '#64748b',
                  fontSize: '0.6875rem',
                  display: 'block',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {userEmail}
              </Typography>
            </Box>
            <Tooltip title="Sign out">
              <IconButton
                onClick={handleLogout}
                size="small"
                sx={{
                  color: '#64748b',
                  '&:hover': {
                    color: '#ef4444',
                    backgroundColor: '#ef444420',
                  },
                }}
              >
                <Logout fontSize="small" />
              </IconButton>
            </Tooltip>
          </Box>
        </Box>
      </Drawer>

      {/* Main Content */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          backgroundColor: '#0f172a',
          minHeight: '100vh',
          overflow: 'auto',
        }}
      >
        {children}
      </Box>
    </Box>
  );
});

export default Layout;
