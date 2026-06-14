import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

const BASE = 'http://localhost:8080/api/users';

@Injectable({ providedIn: 'root' })
export class ApiService {
  constructor(private http: HttpClient) {}

  register(name: string, email: string) {
    return this.http.post<{ message: string; otp: string }>(
      `${BASE}/register`, { name, email }
    );
  }

  verifyOtp(email: string, otp: string) {
    return this.http.post<{ message: string }>(
      `${BASE}/verify-otp`, { email, otp }
    );
  }

  getUsers() {
    return this.http.get<any[]>(BASE);
  }

  deleteUser(id: number) {
    return this.http.delete<{ message: string }>(`${BASE}/${id}`);
  }
}
