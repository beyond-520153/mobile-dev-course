package com.example.kfc.repository;

import com.example.kfc.domain.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * 会员账户 —— 持久化层 Repository
 */
@Repository
public interface MemberRepository extends JpaRepository<Member, Long> {

    Optional<Member> findByUserId(Long userId);

    boolean existsByUserId(Long userId);
}
