package com.pulseauth.pulseauth.service;

import com.pulseauth.pulseauth.dto.LoginRequest;
import com.pulseauth.pulseauth.dto.SignupRequest;
import com.pulseauth.pulseauth.entity.User;
import com.pulseauth.pulseauth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;
import java.util.Random;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final StringRedisTemplate redisTemplate;
    private final EmailService emailService;

    @CacheEvict(value = "users", allEntries = true)
    public String signup(SignupRequest req) {
        if (userRepository.existsByEmail(req.getEmail())) {
            throw new IllegalArgumentException("Email already registered");
        }
        User user = new User();
        user.setName(req.getName());
        user.setEmail(req.getEmail());
        user.setPassword(req.getPassword());
        userRepository.save(user);

        String otp = String.format("%06d", new Random().nextInt(999999));
        redisTemplate.opsForValue().set("otp:" + req.getEmail(), otp, Duration.ofMinutes(5));
        emailService.sendOtp(req.getEmail(), otp);

        return "OTP sent to " + req.getEmail();
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    public String verifyOtp(String email, String otp) {
        String stored = redisTemplate.opsForValue().get("otp:" + email);
        if (stored == null) throw new IllegalStateException("OTP expired or not found");
        if (!stored.equals(otp)) throw new IllegalArgumentException("Invalid OTP");

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setVerified(true);
        userRepository.save(user);
        redisTemplate.delete("otp:" + email);
        return "Verified";
    }

    public User login(LoginRequest req) {
        User user = userRepository.findByEmail(req.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));
        if (!user.getVerified()) throw new IllegalStateException("Account not verified");
        if (!user.getPassword().equals(req.getPassword())) {
            throw new IllegalArgumentException("Invalid email or password");
        }
        return user;
    }

    @Cacheable(value = "users")
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    @Cacheable(value = "user", key = "#id")
    public User getUserById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    public void deleteUser(Long id) {
        if (!userRepository.existsById(id)) throw new IllegalArgumentException("User not found");
        userRepository.deleteById(id);
    }
}
