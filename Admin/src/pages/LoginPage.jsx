/**
 * Admin Login Page
 * Professional authentication page for administrators
 */

import { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../services/firebase';
import {
  Box,
  TextField,
  Button,
  Typography,
  Alert,
  InputAdornment,
  IconButton,
} from '@mui/material';
import {
  Visibility,
  VisibilityOff,
  Lock,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await signInWithEmailAndPassword(auth, email, password);
      navigate('/');
    } catch (err) {
      // Provide user-friendly error messages
      if (err.code === 'auth/invalid-credential' || err.code === 'auth/wrong-password') {
        setError('Invalid email or password');
      } else if (err.code === 'auth/user-not-found') {
        setError('No account found with this email');
      } else if (err.code === 'auth/too-many-requests') {
        setError('Too many failed login attempts. Please try again later');
      } else {
        setError(err.message);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        minHeight: '100vh',
        backgroundColor: '#0f172a',
        p: 2,
      }}
    >
      <Box
        sx={{
          width: '100%',
          maxWidth: 400,
        }}
      >
        {/* Logo/Brand */}
        <Box sx={{ textAlign: 'center', mb: 4 }}>
          <Box
            sx={{
              width: 56,
              height: 56,
              borderRadius: 2,
              backgroundColor: '#1e293b',
              border: '1px solid #334155',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              mx: 'auto',
              mb: 2,
            }}
          >
            <Lock sx={{ color: '#3b82f6', fontSize: 28 }} />
          </Box>
          <Typography
            variant="h4"
            sx={{
              fontWeight: 700,
              color: '#f1f5f9',
              letterSpacing: '-0.02em',
              mb: 0.5,
            }}
          >
            Celestia Admin
          </Typography>
          <Typography
            variant="body2"
            sx={{ color: '#64748b' }}
          >
            Sign in to access the dashboard
          </Typography>
        </Box>

        {/* Login Form */}
        <Box
          sx={{
            backgroundColor: '#1e293b',
            borderRadius: 2,
            border: '1px solid #334155',
            p: 4,
          }}
        >
          {error && (
            <Alert
              severity="error"
              sx={{
                mb: 3,
                backgroundColor: '#ef444420',
                color: '#fca5a5',
                border: '1px solid #ef444440',
                '& .MuiAlert-icon': {
                  color: '#ef4444',
                },
              }}
            >
              {error}
            </Alert>
          )}

          <form onSubmit={handleLogin}>
            <Box sx={{ mb: 3 }}>
              <Typography
                variant="body2"
                sx={{
                  color: '#94a3b8',
                  fontWeight: 500,
                  mb: 1,
                  fontSize: '0.8125rem',
                }}
              >
                Email
              </Typography>
              <TextField
                fullWidth
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoFocus
                disabled={loading}
                placeholder="admin@example.com"
                size="small"
                sx={{
                  '& .MuiOutlinedInput-root': {
                    backgroundColor: '#0f172a',
                    '& input': {
                      color: '#f1f5f9',
                      '&::placeholder': {
                        color: '#475569',
                        opacity: 1,
                      },
                    },
                  },
                }}
              />
            </Box>

            <Box sx={{ mb: 3 }}>
              <Typography
                variant="body2"
                sx={{
                  color: '#94a3b8',
                  fontWeight: 500,
                  mb: 1,
                  fontSize: '0.8125rem',
                }}
              >
                Password
              </Typography>
              <TextField
                fullWidth
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={loading}
                placeholder="Enter your password"
                size="small"
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton
                        onClick={() => setShowPassword(!showPassword)}
                        edge="end"
                        size="small"
                        sx={{ color: '#64748b' }}
                      >
                        {showPassword ? <VisibilityOff fontSize="small" /> : <Visibility fontSize="small" />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    backgroundColor: '#0f172a',
                    '& input': {
                      color: '#f1f5f9',
                      '&::placeholder': {
                        color: '#475569',
                        opacity: 1,
                      },
                    },
                  },
                }}
              />
            </Box>

            <Button
              fullWidth
              variant="contained"
              type="submit"
              disabled={loading}
              sx={{
                py: 1.25,
                backgroundColor: '#3b82f6',
                fontWeight: 600,
                '&:hover': {
                  backgroundColor: '#2563eb',
                },
                '&:disabled': {
                  backgroundColor: '#3b82f680',
                  color: '#f1f5f980',
                },
              }}
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </Button>
          </form>
        </Box>

        {/* Footer */}
        <Typography
          variant="caption"
          sx={{
            display: 'block',
            textAlign: 'center',
            color: '#475569',
            mt: 3,
          }}
        >
          Protected admin area. Unauthorized access prohibited.
        </Typography>
      </Box>
    </Box>
  );
}
