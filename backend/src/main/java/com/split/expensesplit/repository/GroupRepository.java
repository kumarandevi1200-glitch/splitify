package com.split.expensesplit.repository;

import com.split.expensesplit.entity.Group;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GroupRepository extends JpaRepository<Group, Long> {
    @Query("SELECT g FROM Group g JOIN g.members m WHERE m.id = :userId ORDER BY g.createdAt DESC")
    List<Group> findByMembersId(@Param("userId") Long userId);
}
