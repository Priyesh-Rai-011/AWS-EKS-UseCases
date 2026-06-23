import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

const BASE = 'http://a490d91c6f7ce464c95cbe4f08789fd6-921409174.ap-south-1.elb.amazonaws.com/api/users';

@Injectable({ providedIn: 'root' })
export class ApiService {
  constructor(private http: HttpClient) {}

  register(name: string, email: string, password: string) {
    return this.http.post<{ message: string }>(
      `${BASE}/signup`, { name, email, password }
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
