
PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = {params.ball} 
    self.level = params.level
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)
    self.powerup = Powerup()
    self.hasKey = false 
    self.counter = 0
    self.keyconsumed = false
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    self.powerup.spawner = self.counter
    if not self.powerup.inPlay and self.powerup.spawner == 2 then
        if self.hasKey == false and self:haslockedbrick() then
            self.powerup.type = 10 
            self.powerup.inPlay = true
        else
            self.powerup.type = math.random(1,9)
            self.powerup.inPlay = true
        end
        
    end

    if self.powerup.inPlay then
        self.powerup:update(dt)
    end

     
    if self.powerup:collides(self.paddle) then
        if self.powerup.type == 10 then
            self.hasKey= true
            gSounds['recover']:play()
        
        elseif self.powerup.type == 9 then
            local b = Ball(math.random(7))
            b.x = self.balls[1].x
            b.y = self.balls[1].y
            b.dx = math.random(-200, 200)
            b.dy = math.random(-50, -60)
            table.insert(self.balls, b)
            local b2 = Ball(math.random(7))
            b2.x = self.balls[1].x
            b2.y = self.balls[1].y
            b2.dx = math.random(-200, 200)
            b2.dy = math.random(-50, -60)
            table.insert(self.balls, b2)
            local b3 = Ball(math.random(7))
            b3.x = self.balls[1].x
            b3.y = self.balls[1].y
            b3.dx = math.random(-200, 200)
            b3.dy = math.random(-50, -60)
            table.insert(self.balls, b3)
            gSounds['recover']:play()
        
        elseif self.powerup.type == 8 then
            self.score = self.score + 1000
            gSounds['recover']:play()

        elseif self.powerup.type == 7 then
            self.score = self.score - 500
            gSounds['hurt']:play()
    
        elseif self.powerup.type == 6 then
            self.paddle.size = 4
            gSounds['recover']:play()
        
        elseif self.powerup.type == 5 then
            self.paddle.size = 1
            gSounds['hurt']:play()
        
        elseif self.powerup.type == 4 then
            gSounds['recover']:play()
            gStateMachine:change('victory', {
                level = self.level,
                paddle = self.paddle,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                ball = Ball(math.random(7)),
                recoverPoints = self.recoverPoints
            })

        elseif self.powerup.type == 3 then
            if self.health < 3 then
                self.health = self.health + 1
            end
            gSounds['recover']:play()
        
        elseif self.powerup.type == 2 then
            self.score = self.score + math.random(1,100)
            gSounds['recover']:play()
        elseif self.powerup.type == 1 then
            self.health = self.health -1
            gSounds['hurt']:play()
        end
        

    end

    self.paddle:update(dt)

    for i, ball in pairs(self.balls) do
        ball:update(dt)

        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy
            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end

        -- detect collision across all bricks with the balls
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then
                if self.hasKey and brick.locked then
                    brick:hit()
                    brick.locked = false
                    self.keyconsumed = false
                    self.hasKey = false
                end
                self.score = self.score + (brick.tier * 200 + brick.color * 25)
                -- trigger the brick's hit function, which removes it from play
                brick:hit()
                --checker to spawn powerups
                self.counter = self.counter + 1
                if self.counter > 3 then
                    self.counter = 0
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = Ball(math.random(7)),
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end

        -- if ball goes below bounds, revert to serve state and decrease health
        if ball.y >= VIRTUAL_HEIGHT then
            if #self.balls == 1 then
                self.health = self.health - 1
                gSounds['hurt']:play()
                --powerup upate 10

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            else
                table.remove(self.balls, i)
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    if self.hasKey then
        if self.keyconsumed == false then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][10], 5, 0)
        love.graphics.setFont(gFonts['small'])
        love.graphics.print('You have the key', 23, 7)
        else
        love.graphics.setFont(gFonts['small'])
        love.graphics.print(':)', 5, 5)
        end
    end


    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    self.powerup:render()
    for i, ball in pairs(self.balls) do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end


function PlayState:haslockedbrick()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay and brick.locked then
            return true
        end
    end
    return false
end