package com.example.kfc.repository;

import com.example.kfc.domain.entity.MemberCard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 已开通会员卡 —— 持久化层 Repository
 */
@Repository
public interface MemberCardRepository extends JpaRepository<MemberCard, Long> {

    List<MemberCard> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<MemberCard> findByUserIdAndStatusOrderByExpireAtDesc(Long userId, String status);

    /** 同一用户同一类型只保留一张有效卡，续费时在它上面叠加天数 */
    Optional<MemberCard> findFirstByUserIdAndCardTypeAndStatusOrderByExpireAtDesc(
            Long userId, String cardType, String status);

    boolean existsByCardNo(String cardNo);
}
