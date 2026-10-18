package com.example.kfc.repository;

import com.example.kfc.domain.entity.BenefitUsage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * 权益使用流水 —— 持久化层 Repository
 */
@Repository
public interface BenefitUsageRepository extends JpaRepository<BenefitUsage, Long> {

    /** 某天某条规则用了几次 */
    Optional<BenefitUsage> findByUserIdAndRuleCodeAndUseDate(Long userId, String ruleCode, LocalDate useDate);

    /** 某人当天的全部用量，一次查出来算「今日已用」 */
    List<BenefitUsage> findByUserIdAndUseDate(Long userId, LocalDate useDate);
}
