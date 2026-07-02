package com.split.expensesplit.repository;

import com.split.expensesplit.entity.GroupInviteCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GroupInviteCodeRepository extends JpaRepository<GroupInviteCode, Long> {
    Optional<GroupInviteCode> findByCode(String code);
    boolean existsByCode(String code);
}
