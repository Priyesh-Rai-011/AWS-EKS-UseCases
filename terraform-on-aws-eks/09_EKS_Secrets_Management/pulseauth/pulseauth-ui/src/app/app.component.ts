import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from './api.service';

type View = 'users' | 'register' | 'verify';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  view: View = 'users';

  users: any[] = [];
  loadingUsers = false;

  regName = '';
  regEmail = '';
  regOtp = '';
  regMessage = '';
  regError = '';

  verEmail = '';
  verOtp = '';
  verMessage = '';
  verError = '';

  constructor(private api: ApiService) {
    this.loadUsers();
  }

  setView(v: View) {
    this.view = v;
    if (v === 'users') this.loadUsers();
  }

  loadUsers() {
    this.loadingUsers = true;
    this.api.getUsers().subscribe({
      next: u => { this.users = u; this.loadingUsers = false; },
      error: () => { this.loadingUsers = false; }
    });
  }

  register() {
    this.regMessage = ''; this.regError = '';
    this.api.register(this.regName, this.regEmail).subscribe({
      next: r => { this.regOtp = r.otp; this.regMessage = r.message; },
      error: e => { this.regError = e.error?.message || 'Registration failed'; }
    });
  }

  verify() {
    this.verMessage = ''; this.verError = '';
    this.api.verifyOtp(this.verEmail, this.verOtp).subscribe({
      next: r => { this.verMessage = r.message; },
      error: e => { this.verError = e.error?.message || 'Verification failed'; }
    });
  }

  deleteUser(id: number) {
    this.api.deleteUser(id).subscribe({
      next: () => this.loadUsers()
    });
  }
}
