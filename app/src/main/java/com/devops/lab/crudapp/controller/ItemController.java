package com.devops.lab.crudapp.controller;

import com.devops.lab.crudapp.model.Item;
import com.devops.lab.crudapp.service.ItemService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * REST Controller for Item CRUD operations
 */
@RestController
@RequestMapping("/api/items")
@CrossOrigin(origins = "*")
public class ItemController {

    @Autowired
    private ItemService itemService;

    /**
     * Home/Health endpoint
     */
    @GetMapping("/")
    public ResponseEntity<Map<String, String>> home() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("message", "CRUD Application is running successfully!");
        response.put("version", "1.0.0");
        return ResponseEntity.ok(response);
    }

    /**
     * Get all items
     * GET /api/items
     */
    @GetMapping
    public ResponseEntity<List<Item>> getAllItems() {
        List<Item> items = itemService.getAllItems();
        return ResponseEntity.ok(items);
    }

    /**
     * Get item by ID
     * GET /api/items/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<Item> getItemById(@PathVariable Long id) {
        return itemService.getItemById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Create new item
     * POST /api/items
     */
    @PostMapping
    public ResponseEntity<Item> createItem(@Valid @RequestBody Item item) {
        Item createdItem = itemService.createItem(item);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdItem);
    }

    /**
     * Update existing item
     * PUT /api/items/{id}
     */
    @PutMapping("/{id}")
    public ResponseEntity<Item> updateItem(@PathVariable Long id, @Valid @RequestBody Item itemDetails) {
        try {
            Item updatedItem = itemService.updateItem(id, itemDetails);
            return ResponseEntity.ok(updatedItem);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Delete item
     * DELETE /api/items/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteItem(@PathVariable Long id) {
        try {
            itemService.deleteItem(id);
            Map<String, String> response = new HashMap<>();
            response.put("message", "Item deleted successfully");
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Search items by name
     * GET /api/items/search?name={name}
     */
    @GetMapping("/search")
    public ResponseEntity<List<Item>> searchItems(@RequestParam String name) {
        List<Item> items = itemService.searchItemsByName(name);
        return ResponseEntity.ok(items);
    }

    /**
     * Get items by max price
     * GET /api/items/price?max={maxPrice}
     */
    @GetMapping("/price")
    public ResponseEntity<List<Item>> getItemsByPrice(@RequestParam Double max) {
        List<Item> items = itemService.getItemsByMaxPrice(max);
        return ResponseEntity.ok(items);
    }

}
