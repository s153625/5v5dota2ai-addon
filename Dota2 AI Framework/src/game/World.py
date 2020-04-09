#!/usr/bin/env python3
import math

from src.game.BaseNPC import BaseNPC
from src.game.Tower import Tower
from src.game.Tree import Tree
from src.game.Building import Building
from src.game.Hero import Hero
from src.game.PlayerHero import PlayerHero


class World:
    def __init__(self):
        self.entities = {}

    def _update(self, world):
        new_entities = {}
        for eid, data in world.items():
            entity = None
            if eid in self.entities:
                entity = self.entities[eid]
                entity.setData(data)
            else:
                entity = self._create_entity_from_data(data)
            new_entities[eid] = entity
        self.entities = new_entities

    def _create_entity_from_data(self, data):
        if data["type"] == "Hero" and data["team"] == 2:
            return PlayerHero(data)
        elif data["type"] == "Hero":
            return Hero(data)
        elif data["type"] == "Tower":
            return Tower(data)
        elif data["type"] == "Building":
            return Building(data)
        elif data["type"] == "BaseNPC":
            return BaseNPC(data)

    def _get_player_heroes(self):
        heroes = []
        for entity in self.entities.values():
            if isinstance(entity, PlayerHero):
                heroes.append(entity)
        return heroes

    def find_entity_by_name(self, name):
        for entity in self.entities.values():
            if entity.getName() == name:
                return entity

    def get_distance(self, entity1, entity2):
        x1, y1, z1 = entity1.getOrigin()
        x2, y2, z2 = entity2.getOrigin()

        return math.sqrt(((x2 - x1) ** 2) + ((y2 - y1) ** 2))

    def get_id(self, entity):
        for id, ent in self.entities.items():
            if entity == ent:
                return int(id)

    def get_enemies_in_attack_range(self, entity):
        enemies = []
        for ent in self.entities.values():
            if ent.getTeam() == entity.getTeam():
                continue
            if self.get_distance(entity, ent) > entity.getAttackRange():
                continue
            if ent.isAlive():
                enemies.append(ent)

        return enemies

    def get_enemy_towers(self, entity):
        towers = []

        for entity in self.entities:
            if isinstance(entity, Tower) and entity.getTeam() != entity.getTeam():
                towers.append(entity)

    def get_friendly_creeps(self, entity):
        creeps = []

        for e in self.entities:
            if isinstance(e, Building):
                continue
            if isinstance(e, Hero):
                continue
            if e.getTeam() == entity.getTeam():
                creeps.append(e)

        return creeps
