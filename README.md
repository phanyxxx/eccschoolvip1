# 🎓 EduTrack Student Management System

A full-stack Student Management System with Role-Based Access, Score Tracking, Charts, and PDF Reports.

---

## 📦 Project Structure

```
student-management/
├── index.html          ← Complete frontend SPA (works standalone via localStorage)
├── database.sql        ← MySQL schema + seed data
├── .htaccess           ← Apache URL routing
├── api/
│   ├── config.php      ← DB connection, JWT auth, helpers
│   ├── auth.php        ← Login / JWT endpoint
│   ├── students.php    ← Students CRUD API
│   ├── scores.php      ← Scores CRUD + statistics API
│   └── courses.php     ← Courses management API
└── README.md
```

---

## 🚀 Quick Start (Standalone Demo)

1. Open `index.html` in any modern browser — **no server needed**.
2. Login with:

| Role    | Username  | Password    |
|---------|-----------|-------------|
| Admin   | admin     | admin123    |
| Student | sophea    | sophea123   |
| Parent  | parent1   | parent123   |

---

## 🗄️ Full-Stack Setup (PHP + MySQL)

### 1. Database

```bash
mysql -u root -p < database.sql
```

### 2. PHP Backend

Requirements:
- PHP 8.1+
- MySQL 8.0+ / MariaDB 10.6+
- Apache with `mod_rewrite` enabled

Place the project in your web server root (e.g., `/var/www/html/sms/` or XAMPP `htdocs/sms/`).

Edit `api/config.php`:
```php
define('DB_HOST', 'localhost');
define('DB_NAME', 'student_management');
define('DB_USER', 'your_db_user');
define('DB_PASS', 'your_db_password');
define('JWT_SECRET', 'your-very-long-random-secret-here');
```

### 3. Connect Frontend to Backend

In `index.html`, the frontend uses localStorage by default (demo mode).

To connect to the real PHP API, replace the `DB` helper functions with `fetch()` calls to your API endpoints:

```js
// Example: fetch students from real backend
async function fetchStudents() {
  const res = await fetch('/sms/api/students.php', {
    headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token') }
  });
  const json = await res.json();
  return json.data.students;
}
```

---

## 🔑 API Endpoints

### Auth
```
POST /api/auth.php?action=login    { username, password }
GET  /api/auth.php?action=me       Bearer <token>
```

### Students
```
GET    /api/students.php                  ?q=&course_id=&gender=&page=&per_page=
GET    /api/students.php?id=X
POST   /api/students.php                  { name, gender, age, dob, pob, parent_name, parent_phone, course_id, username?, password? }
PUT    /api/students.php?id=X
DELETE /api/students.php?id=X
```

### Scores
```
GET    /api/scores.php?student_id=X
GET    /api/scores.php?action=stats
POST   /api/scores.php                    { student_id, week_label, attendance?, homework?, worksheet?, voice_message?, monthly_test? }
PUT    /api/scores.php?id=X
DELETE /api/scores.php?id=X
```

### Courses
```
GET    /api/courses.php
POST   /api/courses.php                   { name, score_type }
PUT    /api/courses.php?id=X
DELETE /api/courses.php?id=X
```

---

## 📊 Score System

| Course                     | Components                                |
|----------------------------|-------------------------------------------|
| ត្រៀមប្រឡងបាក់ឌុប        | Homework (25) + Monthly Test (25)         |
| វេយ្យាករណ៍អង់គ្លេស        | Attendance (5) + Worksheet (20) + Test (25)|
| អង់គ្លេសថ្នាក់ទី៦         | Attendance (5) + Voice (20) + Test (25)   |
| Beginner សម្រាប់កុមារ     | Attendance (5) + Voice (20) + Test (25)   |
| The English Alphabets      | Attendance (5) + Voice (20) + Test (25)   |
| The Vocabulary             | Attendance (5) + Worksheet (20) + Test (25)|

**Grading Scale:**
- A: ≥ 45 — Excellent
- B: ≥ 40 — Good  
- C: ≥ 35 — Average
- D: ≥ 25 — Below Average
- F: < 25  — Fail

---

## 🎨 Features

### Admin
- ✅ Dashboard with live stats and Chart.js charts
- ✅ Full CRUD for students (add/edit/delete with modals)
- ✅ Score entry with sliders + auto-calculated totals
- ✅ Score history per student
- ✅ Daily attendance tracking
- ✅ Report cards with Print/PDF export
- ✅ Course management (add/edit/delete)
- ✅ Search, filter, and pagination
- ✅ Dark mode toggle
- ✅ Toast notifications

### Student
- ✅ Personal profile view
- ✅ Score history with trend chart
- ✅ Report card with PDF export

### Parent
- ✅ Child's progress overview
- ✅ Full score history view

---

## 🔐 Security Notes

- Passwords are **bcrypt-hashed** (PHP backend)
- JWT tokens expire after **24 hours**
- Score validation enforces **per-field maximums**
- Change `JWT_SECRET` and DB credentials before deployment
- In production, use HTTPS and rate-limit the auth endpoint

---

## 🛠 Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| Frontend  | HTML5, CSS3, Bootstrap 5, Chart.js  |
| Backend   | PHP 8.1 (pure, no framework)        |
| Database  | MySQL 8.0 with generated columns    |
| Auth      | JWT (HS256)                         |
| Fonts     | Playfair Display, DM Sans, Noto Serif Khmer |

---

*EduTrack SMS v1.0 — Built with ❤️*
