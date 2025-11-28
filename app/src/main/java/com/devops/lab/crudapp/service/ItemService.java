package com.devops.lab.crudapp.service;

import com.devops.lab.crudapp.model.Item;
import com.devops.lab.crudapp.repository.ItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Service class for Item business logic
 */
@Service
public class ItemService {

    @Autowired
    private ItemRepository itemRepository;

    /**
     * Get all items
     */
    public List<Item> getAllItems() {
        return itemRepository.findAll();
    }

    /**
     * Get item by ID
     */
    public Optional<Item> getItemById(Long id) {
        return itemRepository.findById(id);
    }

    /**
     * Create new item
     */
    public Item createItem(Item item) {
        return itemRepository.save(item);
    }

    /**
     * Update existing item
     */
    public Item updateItem(Long id, Item itemDetails) {
        Item item = itemRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Item not found with id: " + id));

        item.setName(itemDetails.getName());
        item.setDescription(itemDetails.getDescription());
        item.setPrice(itemDetails.getPrice());
        item.setQuantity(itemDetails.getQuantity());

        return itemRepository.save(item);
    }

    /**
     * Delete item
     */
    public void deleteItem(Long id) {
        Item item = itemRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Item not found with id: " + id));
        itemRepository.delete(item);
    }

    /**
     * Search items by name
     */
    public List<Item> searchItemsByName(String name) {
        return itemRepository.findByNameContainingIgnoreCase(name);
    }

    /**
     * Get items by max price
     */
    public List<Item> getItemsByMaxPrice(Double maxPrice) {
        return itemRepository.findByPriceLessThanEqual(maxPrice);
    }

}
