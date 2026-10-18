package com.example.kfc.repository;

import com.example.kfc.domain.entity.BenefitRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

/**
 * 会员卡权益规则 —— 持久化层 Repository
 */
@Repository
public interface BenefitRuleRepository extends JpaRepository<BenefitRule, Long> {

    /** 全部生效规则，按计算顺序排列 */
    List<BenefitRule> findByStatusOrderBySortOrderAsc(Integer status);

    /** 只取该用户手上卡类型对应的规则 */
    List<BenefitRule> findByCardTypeInAndStatusOrderBySortOrderAsc(Collection<String> cardTypes, Integer status);

    Optional<BenefitRule> findByCode(String code);
}
