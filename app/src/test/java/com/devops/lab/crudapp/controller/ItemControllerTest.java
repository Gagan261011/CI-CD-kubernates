package com.devops.lab.crudapp.controller;

import com.devops.lab.crudapp.model.Item;
import com.devops.lab.crudapp.service.ItemService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ItemController.class)
class ItemControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ItemService itemService;

    private Item testItem;
    private List<Item> testItems;

    @BeforeEach
    void setUp() {
        testItem = new Item(1L, "Test Item", "Test Description", 99.99, 10);
        testItems = Arrays.asList(
                testItem,
                new Item(2L, "Item 2", "Description 2", 49.99, 5)
        );
    }

    @Test
    void testHomeEndpoint() throws Exception {
        mockMvc.perform(get("/api/items/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void testGetAllItems() throws Exception {
        when(itemService.getAllItems()).thenReturn(testItems);

        mockMvc.perform(get("/api/items"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].name").value("Test Item"));
    }

    @Test
    void testGetItemById() throws Exception {
        when(itemService.getItemById(1L)).thenReturn(Optional.of(testItem));

        mockMvc.perform(get("/api/items/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Test Item"))
                .andExpect(jsonPath("$.price").value(99.99));
    }

    @Test
    void testGetItemById_NotFound() throws Exception {
        when(itemService.getItemById(anyLong())).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/items/999"))
                .andExpect(status().isNotFound());
    }

    @Test
    void testCreateItem() throws Exception {
        when(itemService.createItem(any(Item.class))).thenReturn(testItem);

        String itemJson = "{\"name\":\"Test Item\",\"description\":\"Test Description\",\"price\":99.99,\"quantity\":10}";

        mockMvc.perform(post("/api/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(itemJson))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Test Item"));
    }

}
