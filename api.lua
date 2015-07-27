--File: skillsFramework/api.lua
--Author: Domtron Vox(domtron.vox@gmail.com)
--Description: Set of functions that make up the API

--shows a formspec for skill GUI interaction.
SkillsFramework.show_formspec = function(playername, page)
        local SF = SkillsFramework --shorten variable name
        local formspec = "size[8,9]" --define formspec var and set ui size
        
        --get number of skills owned by the player
        local skill_count = 0
        if SF.__skillsets[playername] ~= nil then
            for v,b in pairs(SF.__skillsets[playername]) do
                skill_count = skill_count + 1
            end
        end

        --player skillset does not exist
        if SF.__skillsets[playername] == nil then
        
            local formspec = formspec .. "label[1.5,1.5;Player has no skillset attached. Ask admin!]"
            console.log("[SKILLSFRAMEWORK, WARNING] Player "..
                        playername .. " does not have a skillset attached.")

        --player has no skills
        elseif skill_count == 0 then --SF.__skillsets[playername] == 0 then

            formspec = formspec .. "label[1.5,1.5;Player has not learned any skills!]"

        --player skillset does exist and has skills in it
        else 
            local skills_per_page = 18 -- how many skills fit on a page

            page = page or 1 --default to 1 if no page is given.
            formspec =  formspec .. "tabheader[0,0;skills_page;"

            --define the names of the tab buttons
            for i = 1,math.ceil(skill_count / skills_per_page)do
                formspec = formspec .. "Page " .. i .. ","
            end

            --cut out the last comma and close out the tabheader
            formspec = string.sub(formspec, 1, -2)
            formspec = formspec .. ";" .. page .. "]"

            --now step through and create a entry for each skill the character has 
            local y_index = 0 --vertical location to place the next skill
            local skills_iter = 1 --number of skills we have iterated over
            
            for skill_id,skill_data in pairs(SF.__skillsets[playername]) do

                --print(skills_iter..","..skills_per_page..","..page..","
                --      ..skills_per_page*page..","..skills_per_page*page - skills_per_page)
                --print(skills_iter > skills_per_page*page)
                --print(skills_iter < skills_per_page*page - skills_per_page)
                --do not add a skill and exp bar if the current skill belongs on another page
                if skills_iter > skills_per_page*page or
                   skills_iter < skills_per_page*page - skills_per_page then
                    break

                else -- add skill to formspec
                
                    formspec = formspec 
                               .. "image[0," .. y_index * .5 + .1 .. ";1.5,.4;" 
                               .. SF.__generate_bar(playername, skill_id) .. "]" 
                               .. "label[1.5," .. y_index * .5 .. ";" 
                               .. skill_id:split(":")[2] --remove the mod name from the skill name
                               .. "]"
                    y_index = y_index + 1
                end

                skills_iter = skills_iter + 1

            end --finished adding skills to the page

        end --finished adding things to the formspec
        
	minetest.show_formspec(playername, "skillsframework:display", formspec)
end

--Adds a new skill definition to the skill system. Data contains:
--  name       : skill's name
--  mod        : registering mod
--  level_func : called on level up; receives skill level integer 
--  group      : name of group the skill belongs to
--  min        : start level value and minimum level
--  max        : maximum level value
SkillsFramework.define_skill = function(data)
    --TODO test that values are the right types (ints, strings, ect)
    --make sure required values are in the table.
    if not data.name then
        minetest.log("[SKILLSFRAMEWORK, WARNING] Skill registered without name. Skill discarded.")
        return 
    end

    if not data.mod then
        minetest.log("[SKILLSFRAMEWORK, WARNING] Skill "
                     ..data.name
                     .." registration without mod name. Skill discarded.")
        return
    end

    if not data.level_func then
        minetest.log("[SKILLSFRAMEWORK, WARNING] Skill "
                     ..data.mod..':'..data.name
                     .." registration without level cost function. Skill discarded.")
        return
    end

    -- do sanity checks on min and max
    if data.min and data.min < 0 then
        minetest.log("[SKILLSFRAMEWORK, WARNING] Skill "
                     ..data.mod..':'..data.name
                     .."'s min data is less then zero. Setting to zero instead.")
        data.min = 0
    end

    if data.max and data.max < 0 then
        minetest.log("[SKILLSFRAMEWORK, WARNING] Skill "
                     ..data.mod..':'..data.name
                     .."'s max data is less then zero. Setting to zero instead.")
        data.max = 0
    end

    --create entry for the new skill
    SkillsFramework.__skill_defs[data.mod..':'..data.name] = {
        ["name"] = data.name,              --skill name
        ["mod"] = data.mod,                --name of registering mod
        ["group"] = data.group,            --grouping name
        ["level_func"] = data.level_func,  --function that calculates each levels cost
        ["min"] = data.min or 0,           --minimum level
        ["max"] = data.max or 0,           --maximum level
    }

    --skills are listed on the formspec in the order they are registered.
    table.insert(SkillsFramework.__skills_list, data.mod..':'..data.name)
end


--Creates and then attaches a new skill set to the given identifier.
--  set_id    : skill set id 
--  skills    : table of skill ids or nil 
SkillsFramework.attach_skillset = function(set_id, skills)
    local skill_defs = SkillsFramework.__skill_defs
    SkillsFramework.__skillsets[set_id] = {}
    local skill_set = SkillsFramework.__skillsets[set_id]

    --default action of adding all skills if specific skills where not passed to the skillset.
    if skills == nil then
        --create skill data for each registered skill and populate the new skill set
        for skill_id, v in pairs(skill_defs) do
            SkillsFramework.__instantiate_skilldata(set_id, skill_id)
        end

    --add skills in list
    elseif type(skills) == "table" then
        --get each skill id from the given list and try to add that skill
        for i,skill_id in ipairs(skills) do 
            SkillsFramework.__instantiate_skilldata(set_id, skill_id)
        end

    --passed skill list is an invalid value (not nil or table)
    else
        minetest.log("[SKILLSFRAMEWORK, WARNING] attach_skillset call for "
                     .. set_id 
                     .. " recived an invalid value for skill list. Should be nil or a table.")
    end
end

--Deletes a skill set. 
--  set_id    : skill set id 
SkillsFramework.remove_skillset = function(set_id)
    SkillsFramework.__skillsets[set_id] = nil
end

--Return the level of specified skill.
--  set_id    : skill set id 
--  skill_id  : name of the skill to test
SkillsFramework.get_level = function(set_id, skill_id)
    if SkillsFramework.__skill_entity_exists(set_id, skill_id) then
        return SkillsFramework.__skillsets[set_id][skill_id]["level"]
    else
        return nil --skill or entity does not exist
    end
end

--Allows setting the level of a skill in a skill set.
--  set_id    : skill set id 
--  skill     : name of the skill to test
--  level     : new level to set it to
SkillsFramework.set_level = function(set_id, skill, level)
    if SkillsFramework.__skill_entity_exists(set_id, skill) then
        local skill_def = SkillsFramework.__skill_defs[skill]
        local skill_set = SkillsFramework.__skillsets[set_id][skill]

        --Deny any attempt to set level higher then the max
        if level > skill_def.max and skill_def.max ~= 0 then
            level = skill_def.max
        end

        skill_set["level"] = level

        --calculate new next_level value; if 0 then set to 1 since we need some cost to prevent errors 
        skill_set["next_level"] = skill_def["level_func"](level+1)
        if skill_set["next_level"] == 0 then 
            skill_set["next_level"] = 1 
        end

    end
end

--Returns the cost of the next level be it in experience or progression points.
--  set_id    : skill set id 
--  skill     : name of the skill to test
SkillsFramework.get_next_level_cost = function(set_id, skill)
    if SkillsFramework.__skill_entity_exists(set_id, skill) then
        return SkillsFramework.__skillsets[set_id][skill]["next_level"]
    else
        return nil
    end
end

--Returns the specified skill's experience.
--  set_id    : skill set id 
--  skill     : name of the skill to test
SkillsFramework.get_experience = function(set_id, skill)
    if SkillsFramework.__skill_entity_exists(set_id, skill) then
        return SkillsFramework.__skillsets[set_id][skill]["experience"]
    else
        return nil
    end
end

--Sets the specified skill's experience.
--  set_id    : skill set id 
--  skill     : name of the skill to test
--  experience : amount to set it to
SkillsFramework.set_experience = function(set_id, skill, experience)
    if SkillsFramework.__skill_entity_exists(set_id, skill) then
        local skill_def = SkillsFramework.__skill_defs[skill]
        local skill_set = SkillsFramework.__skillsets[set_id][skill]

        --don't add experience if a level is maxed out.
        if skill_set["level"] >= skill_def.max and skill_def.max ~= 0 then
            return true
        end

        --remove decimal portion
        experience = math.floor(experience + 0.5)

        --set the new experience value and make sure a level up occurs if needed
        SkillsFramework.__skillsets[set_id][skill]["experience"] = experience
        SkillsFramework.__fix_skill_exp_and_level(set_id, skill) --see util.lua


        return true
    else
        return false
    end
end


--##Aliases##--

--Two adder functions that add the given value to the attribute
SkillsFramework.add_level = function(set_id, skill, level)
    return SkillsFramework.set_level(set_id, skill, 
                                   SkillsFramework.get_level(set_id, skill)+level)
end

SkillsFramework.add_experience = function(set_id, skill, experience)
    return SkillsFramework.set_experience(set_id, skill, 
                         SkillsFramework.get_experience(set_id, skill)+experience)
end
