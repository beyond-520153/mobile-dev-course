package com.example.kfc.repository;

import com.example.kfc.domain.entity.MemberPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 会员卡档位 —— 持久化层 Repository
 */
@Repository
public interface MemberPlanRepository extends JpaRepository<MemberPlan, Long> {

    /** 在售档位，按 sortOrder 升序（季卡 / 年卡 / 月卡 的排法就靠它） */
    List<MemberPlan> findByStatusOrderBySortOrderAsc(Integer status);

    List<MemberPlan> findByCardTypeAndStatusOrderBySortOrderAsc(String cardType, Integer status);

    Optional<MemberPlan> findByCode(String code);
}
