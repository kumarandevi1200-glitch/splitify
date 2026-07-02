package com.split.expensesplit.service;

import com.split.expensesplit.config.JwtService;
import com.split.expensesplit.dto.AuthResponse;
import com.split.expensesplit.dto.LoginRequest;
import com.split.expensesplit.dto.RegisterRequest;
import com.split.expensesplit.entity.User;
import com.split.expensesplit.exception.CustomException;
import com.split.expensesplit.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new CustomException("DUPLICATE_EMAIL", "Email is already registered", HttpStatus.BAD_REQUEST);
        }

        User user = new User(
                request.getEmail(),
                passwordEncoder.encode(request.getPassword())
        );

        User savedUser = userRepository.save(user);

        String accessToken = jwtService.generateAccessToken(savedUser.getEmail());
        String refreshToken = jwtService.generateRefreshToken(savedUser.getEmail());

        return new AuthResponse(accessToken, refreshToken, savedUser.getEmail(), savedUser.getId());
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new CustomException("INVALID_CREDENTIALS", "Invalid email or password", HttpStatus.UNAUTHORIZED));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new CustomException("INVALID_CREDENTIALS", "Invalid email or password", HttpStatus.UNAUTHORIZED);
        }

        String accessToken = jwtService.generateAccessToken(user.getEmail());
        String refreshToken = jwtService.generateRefreshToken(user.getEmail());

        return new AuthResponse(accessToken, refreshToken, user.getEmail(), user.getId());
    }

    public AuthResponse refresh(String refreshToken) {
        try {
            String email = jwtService.extractEmail(refreshToken);
            String tokenType = jwtService.extractClaim(refreshToken, claims -> claims.get("token_type", String.class));

            if (!"refresh".equals(tokenType)) {
                throw new CustomException("INVALID_TOKEN", "Provided token is not a refresh token", HttpStatus.BAD_REQUEST);
            }

            User user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new CustomException("INVALID_TOKEN", "User associated with token not found", HttpStatus.UNAUTHORIZED));

            if (jwtService.validateToken(refreshToken, user.getEmail())) {
                String newAccessToken = jwtService.generateAccessToken(user.getEmail());
                String newRefreshToken = jwtService.generateRefreshToken(user.getEmail());
                return new AuthResponse(newAccessToken, newRefreshToken, user.getEmail(), user.getId());
            } else {
                throw new CustomException("TOKEN_EXPIRED", "Refresh token is expired", HttpStatus.UNAUTHORIZED);
            }
        } catch (Exception e) {
            throw new CustomException("INVALID_TOKEN", "Invalid refresh token", HttpStatus.UNAUTHORIZED);
        }
    }
}
