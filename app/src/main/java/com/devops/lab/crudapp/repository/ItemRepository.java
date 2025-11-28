package com.devops.lab.crudapp.repository;

import com.devops.lab.crudapp.model.Item;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Repository interface for Item entity
 */
@Repository
public interface ItemRepository extends JpaRepository<Item, Long> {

    /**
     * Find items by name containing the given string (case-insensitive)
     */
    List<Item> findByNameContainingIgnoreCase(String name);

    /**
     * Find items by price less than or equal to the given value
     */
    List<Item> findByPriceLessThanEqual(Double price);

}
