process.env.PORT = 5066;
const connectDB = require('./src/config/db');
const app = require('./src/app');

const base = 'http://localhost:5066/api';
let token = '';

async function req(method, path, body, auth = true) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth && token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(base + path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json();
  return { status: res.status, data };
}

async function main() {
  await connectDB();
  const server = app.listen(5066, async () => {
    try {
      let r = await req('GET', '/health', null, false);
      console.log('health:', r.status, r.data.message);

      r = await req('POST', '/auth/login', { email: 'admin@muallimcarpets.com', password: 'Admin@123' }, false);
      console.log('admin login:', r.status, r.data.data.user.role);
      token = r.data.data.token;

      r = await req('GET', '/dashboard');
      console.log('dashboard cards:', r.status, JSON.stringify(r.data.data.cards));

      r = await req('GET', '/products?limit=3');
      console.log('products:', r.status, 'total=', r.data.data.total);

      r = await req('GET', '/audit?limit=5');
      console.log('audit logs (admin):', r.status, 'total=', r.data.data.total);

      r = await req('GET', '/reports?period=month');
      console.log('report:', r.status, JSON.stringify({ sales: r.data.data.sales, profit: r.data.data.profit }));

      // Manager login - should be scoped
      const ml = await req('POST', '/auth/login', { email: 'ali@muallimcarpets.com', password: 'Manager@123' }, false);
      token = ml.data.data.token;
      console.log('manager login:', ml.status, 'assignedShop=', ml.data.data.user.assignedShop?.name);

      r = await req('GET', '/products?limit=3');
      console.log('manager products total:', r.data.data.total);

      r = await req('GET', '/audit');
      console.log('manager audit access (should be 403):', r.status);

      r = await req('GET', '/notifications/unread-count');
      console.log('manager unread notifications:', r.status, r.data.data.count);

      console.log('ALL TESTS DONE');
      process.exit(0);
    } catch (e) {
      console.error('TEST ERROR:', e.message);
      process.exit(1);
    }
  });
}

main();
