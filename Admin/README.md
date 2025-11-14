# Celestia Admin Dashboard

Real-time admin dashboard for content moderation, user management, and platform analytics.

## Features

### 🎯 Core Capabilities
- **Real-time Moderation Queue** - Priority-based content review with auto-assignment
- **User Management** - Bulk operations, timeline view, and detailed user analytics
- **Fraud Detection** - Pattern recognition and automated risk assessment
- **Platform Analytics** - Revenue, engagement, and security metrics
- **Audit Logging** - Complete trail of all admin actions

### 🚀 Performance Optimizations
- Query caching (5-minute TTL)
- Optimized Firestore indexes
- Real-time updates via Firebase listeners
- Lazy loading and code splitting

## Getting Started

### Prerequisites
- Node.js 18+
- Firebase project access
- Admin credentials

### Installation

```bash
cd Admin
npm install
```

### Configuration

Create `.env` file:

```env
VITE_FIREBASE_API_KEY=your_api_key
VITE_FIREBASE_AUTH_DOMAIN=your_auth_domain
VITE_FIREBASE_PROJECT_ID=your_project_id
VITE_FIREBASE_STORAGE_BUCKET=your_storage_bucket
VITE_FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id
VITE_FIREBASE_APP_ID=your_app_id
VITE_API_BASE_URL=https://your-cloud-function-url
```

### Development

```bash
npm run dev
```

Open [http://localhost:5173](http://localhost:5173)

### Build

```bash
npm run build
```

## Architecture

### Tech Stack
- **Frontend**: React 18 + Vite
- **UI Framework**: Material-UI (MUI)
- **State Management**: React Context + Hooks
- **Charts**: Recharts
- **Backend**: Firebase Cloud Functions
- **Database**: Firestore
- **Authentication**: Firebase Auth

### Project Structure

```
Admin/
├── src/
│   ├── components/        # Reusable UI components
│   │   ├── Layout.jsx
│   │   ├── Sidebar.jsx
│   │   └── StatCard.jsx
│   ├── pages/            # Page components
│   │   ├── Dashboard.jsx
│   │   ├── ModerationQueue.jsx
│   │   ├── UserManagement.jsx
│   │   ├── Analytics.jsx
│   │   └── AuditLogs.jsx
│   ├── services/         # API and Firebase services
│   │   ├── api.js
│   │   └── firebase.js
│   ├── App.jsx           # Main app component
│   └── main.jsx          # Entry point
├── public/               # Static assets
└── package.json
```

## API Integration

The dashboard connects to Cloud Functions endpoints:

### Admin Dashboard APIs
- `GET /admin/stats` - Platform statistics
- `GET /admin/user-timeline/:userId` - User activity timeline
- `POST /admin/bulk-operation` - Bulk user operations
- `GET /admin/fraud-patterns` - Fraud pattern detection
- `GET /admin/audit-logs` - Admin action logs

### Moderation Queue APIs
- `GET /admin/moderation-queue` - Get prioritized queue
- `POST /admin/moderation-queue/:itemId/assign` - Assign to moderator
- `POST /admin/moderation-queue/:itemId/complete` - Complete review
- `GET /admin/moderation-queue/stats` - Queue statistics
- `POST /admin/moderation-queue/auto-assign` - Auto-assign items

## Features Guide

### Moderation Queue
- **Priority Scoring**: Automatic prioritization based on severity, user history, and SLA
- **Auto-Assignment**: Intelligent workload distribution
- **Real-time Updates**: Live queue updates via Firestore listeners
- **Batch Operations**: Review multiple items efficiently

### User Management
- **User Timeline**: Complete activity history in one view
- **Bulk Operations**: Ban, verify, or grant premium to multiple users
- **Fraud Detection**: Identify suspicious patterns and behaviors
- **Warning System**: Track violations and auto-suspend repeat offenders

### Analytics Dashboard
- **User Metrics**: Total, active, premium, verified counts
- **Engagement**: Matches, messages, retention rates
- **Revenue**: Subscriptions, consumables, refunds
- **Security**: Fraud attempts, pending reviews

### Audit Logging
- Complete history of all admin actions
- Filter by admin, action type, or date range
- Export capabilities for compliance

## Security

### Authentication
- Firebase Auth with admin role verification
- Bearer token authentication for API calls
- Automatic token refresh

### Authorization
- Server-side admin verification on all endpoints
- IP address and user agent logging
- Rate limiting on sensitive operations

## Performance

### Optimizations
- **Caching**: 5-minute TTL on expensive queries (reduces load by ~80%)
- **Pagination**: All lists support pagination
- **Indexes**: Composite Firestore indexes for fast queries
- **Real-time**: Firebase listeners for live updates without polling

### Metrics
- Dashboard load time: < 500ms (vs 5s before caching)
- Moderation queue refresh: < 200ms
- User timeline load: < 1s for 100 events

## Deployment

### Firebase Hosting

```bash
npm run build
firebase deploy --only hosting:admin
```

### Custom Hosting
Build output is in `dist/` directory. Deploy as static site.

## Contributing

1. Follow React best practices
2. Use Material-UI components
3. Add error handling for all API calls
4. Update README for new features

## Support

For issues or questions:
1. Check Cloud Functions logs: `firebase functions:log`
2. Verify Firestore indexes are deployed
3. Ensure admin user has `isAdmin: true` in Firestore

## License

Private - Internal use only
