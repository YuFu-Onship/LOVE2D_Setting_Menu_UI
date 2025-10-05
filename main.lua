-- 文件io部分

-- 关于文件I/O的操作
local FileIO={}
FileIO.__index=FileIO
function FileIO:new()
    local init=setmetatable({},self)
    return init
end
-- 直接写入设置文件并保存
function FileIO:save_setting(tbl,path)
    path=path or "setting.lua"
    local result="return\n"..self:__serialize_table(tbl)
    local ok,err=love.filesystem.write(path,result)
    -- print("Save directory:", love.filesystem.getSaveDirectory())
    return ok,err
end
-- 盘算一个table是类似于"字典(false)"还是"列表(true)"
function FileIO:__is_pure_array(tbl)
    local count=0
    for k,v in pairs(tbl) do
        if type(k)=="number" and k>=1 then
            count=count+1
        else
            return false
        end
    end
    return true
end
-- 序列化table, 可以将table保存到目标文件
function FileIO:__serialize_table(tbl,indent)
    indent=indent or 0
    indent=indent+4
    local spacing=string.rep(" ", indent)
    local result="{\n"
    for k, v in pairs(tbl) do
        -- print(type(k))
        local key=k
        if type(v)=="table" then
            if self:__is_pure_array(v) then
                -- 构建"列表"字符串,保留string元素(包含引号)
                local items={}
                for i,n in ipairs(v)do items[#items+1]=string.format("%q",n) end
                local content="{"..table.concat(items,",").."}"
                result=result..spacing..key.."="..content..",\n"
            else
                result=result..spacing..key.."="..self:__serialize_table(v,indent)..",\n"
            end
        elseif type(v)=="string" then
            result=result..spacing..key.."=".."\""..string.format(v).."\""..",\n"
        else
            result=result..spacing..key.."="..tostring(v)..",\n"
        end
    end
    result = result .. spacing .. "}"
    return result
end


-- [class]更新一个值,当前值在目标值之间往返
local function create_value_trip()
    local v=0
    return function (dt,cur_value,tar_value,speed,mumentum)
        speed=speed or 100
        mumentum=mumentum or 0.95

        local distance=math.abs(tar_value-cur_value)
        local vec=(tar_value-cur_value)/distance
        
        local diff=tar_value-cur_value
        local distance=math.abs(diff)
        
        if distance<=0.015 and v<=0.015 then
            cur_value=tar_value
            v=0
        else
            v=(1-mumentum)*vec*speed*dt+mumentum*v
            cur_value=cur_value+v
        end

        return cur_value
    end
end

-- 更新一个值,动画效果:由快到慢
local function create_value_easeOut()
    local t = 0
    return function (dt, start_value,end_value,duration)
        t=math.min(t+dt,duration)
        local e=t/duration -- t/duration 归一化处理, 
        local p=1-(1-e)^3 -- 当前值=向量*[0,1]之间的某个值
        return (end_value-start_value)*p
    end
end

-- 绘制一个带边的圆角矩形框
local function draw_round_rectangle(x,y,w,h,r,c1,c2)
    local color_1=c1 or {1,1,1,0.2}
    local color_2=c2 or {1,1,1,1.0}
    love.graphics.setColor(unpack(color_1))
    love.graphics.rectangle("fill",x,y,w,h,r)
    love.graphics.setColor(unpack(color_2))
    love.graphics.rectangle("line",x,y,w,h,r)
end

-- {x,y,w,h,r}->{table} 返回八边形的顶点参数
local function octagon_verts(x,y,w,h,r,c)
    local c=c or {1,1,1,1}
    local r=r or 0
    if r==0 then
        return{
            {x,y,0,0,unpack(c)},
            {x+w,y,0,0,unpack(c)},
            {x+w,y+h,0,0,unpack(c)},

            {x,y,0,0,unpack(c)},
            {x,y+h,0,0,unpack(c)},
            {x+w,y+h,0,0,unpack(c)}
        }
    else
        return{
            {x,y+r,0,0,unpack(c)},
            {x+r,y,0,0,unpack(c)},
            {x+w-r,y,0,0,unpack(c)},

            {x,y+r,0,0,unpack(c)},
            {x+w-r,y,0,0,unpack(c)},
            {x+w,y+r,0,0,unpack(c)},

            {x,y+r,0,0,unpack(c)},
            {x+w,y+r,0,0,unpack(c)},
            {x+w,y+h-r,0,0,unpack(c)},

            {x,y+r,0,0,unpack(c)},
            {x,y+h-r,0,0,unpack(c)},
            {x+w,y+h-r,0,0,unpack(c)},

            {x,y+h-r,0,0,unpack(c)},
            {x+w,y+h-r,0,0,unpack(c)},
            {x+w-r,y+h,0,0,unpack(c)},

            {x,y+h-r,0,0,unpack(c)},
            {x+r,y+h,0,0,unpack(c)},
            {x+w-r,y+h,0,0,unpack(c)},
        }
    end
end

-- 创建一个彩色的矩形Mesh
local function colorful_square_mesh(x,y,w,h,c1,c2,c3,c4)
    local c1=c1 or {0.6,0.2,0.8,1}
    local c2=c2 or {0.2,0.4,1.0,1}
    local c3=c3 or {1.0,0.5,0.2,1}
    local c4=c4 or {1.0,0.0,0.0,1}
    local vertices = {
        {x,   y,   0, 0, unpack(c1)},
        {x+w, y,   1, 0, unpack(c2)},
        {x+w, y+h, 1, 1, unpack(c3)},
        {x,   y+h, 0, 1, unpack(c4)},
    }
    local rectMesh = love.graphics.newMesh(vertices, "fan", "static")
    return function() love.graphics.draw(rectMesh, 0, 0) end
end

-- 用于创建进度条的类
local VerticalBar={}
VerticalBar.__index=VerticalBar
function VerticalBar:new(x,y,w,h,distance,value,num)
    local init=setmetatable({},self)
    init.value=value or 0.5
    init.distance=distance or 2
    init.num=num or 20
    init.line_table={}
    init.x=x
    init.y=y
    init.w=w
    init.h=h
   
    init.width=math.floor((init.w-(init.num-1)*init.distance)/init.num)

    init.color_1={1,1,1,1}
    init.color_2={1,1,1,0.5}
    
    init.verts_table={}
    init.oriangle_verts_table={}
    init.mesh=nil
    
    init.line_table=nil
    init.verts_table=nil

    init.call_func={
        ["keypressed"]=function (key)
            if key=="right" then
                init.value=init.value+0.1
            elseif key=="left" then
                init.value=init.value-0.1
            end
            if init.value>=1 then
                init.value=1
            elseif init.value<=0 then
                init.value=0
            end
        end
    }
    -- api
    init.out_cx,init.out_cy=nil,nil
    init.scale=1
    init.is_active=false

    return init
end
function VerticalBar:update(dt)
    local active_count=math.floor(self.value*self.num+0.5)
    self.verts_table={}
    self.width=math.floor((self.w-(self.num-1)*self.distance)/self.num)
    local line_table=self:__creater_new_bar(self.x,self.y)

    for i=1,self.num do
        for n=1,#line_table[i] do
            if i<=active_count then
                self:__change_color(line_table,i,n,self.color_1)
            else
                self:__change_color(line_table,i,n,self.color_2)
            end
            table.insert(self.verts_table,line_table[i][n])
        end
    end

    self.mesh=love.graphics.newMesh(self.verts_table,"triangles","dynamic")
end
function VerticalBar:draw()
    love.graphics.draw(self.mesh)
end
function VerticalBar:__creater_new_bar(x,y)
    local verts={}
    for i=1,self.num do
        local child_x=x+(i-1)*(self.distance+self.width)
        table.insert(verts,octagon_verts(child_x,y,self.width,self.h,0,self.color_1))
    end
    return verts
end
function VerticalBar:__change_color(line_table,i,n,color)
    line_table[i][n][5],line_table[i][n][6],line_table[i][n][7],line_table[i][n][8]=unpack(color)
end
function VerticalBar:api_x_y(x,y)
    self.x=x
    self.y=y
end
function VerticalBar:api_x_y(x,y)
    self.x,self.y=x,y
end
function VerticalBar:api_w_h(w,h)
    self.w=w
    self.h=h
end
function VerticalBar:api_cx_cy(cx,cy)
    self.cx,self.cy=cx,cy
end
function VerticalBar:api_scale(scale)
    self.scale=scale
end
function VerticalBar:api_value(value)
    self.value=value
end

-- 用于创建一个音量显示条ui
local VolumeUI={}
VolumeUI.__index=VolumeUI
-- {x,y,w,h,text.value}
function VolumeUI:new(cx,cy,w,h,text,value,func)
    local init=setmetatable({},self)
    init.text=text or "VolumeUI"
    init.value=value or 0.5

    init.scale=1
    init.target_scale=1
    init.__update_scale=create_value_trip()
    
    init.cx=cx or 0
    init.cy=cy or 0
    init.w=w
    init.h=h

    init.x=init.cx-init.w/2
    init.y=init.cy-init.h/2
    init.square_w=w
    init.square_h=h
    init.square_x=init.cx-init.square_w/2
    init.square_y=init.cy-init.square_h/2

    init.text_x=init.cx-init.w/2+10
    init.text_y=init.cy-(init.h-30)/2

    init.volume_bar_width=200
    init.volume_bar=VerticalBar:new(0,0,init.volume_bar_width,24,2,init.value,30)

    init.func=func or function() end
    init.call_func={
        ["keypressed"]=function (key)
            init.volume_bar.call_func["keypressed"](key)
            if key=="left" then
                init.value=init.value-0.1
            elseif key=="right" then
                init.value=init.value+0.1
            end
            init.value=math.min(1,math.max(0,init.value))
            init.func(init.value)
        end
    }
    init.is_active=false 
    return init
end
function VolumeUI:update(dt)
    self.scale=self.__update_scale(dt,self.scale,self.target_scale,10,0.9)
    self.square_w=self.w*self.scale
    self.square_h=self.h*self.scale
    self.square_x=self.cx-self.square_w/2
    self.square_y=self.cy-self.square_h/2

    self.text_x=self.cx-self.square_w/2+20*self.scale
    self.text_y=self.cy-15*self.scale

    self.volume_bar.is_active=self.is_active
    self.volume_bar:api_x_y(
        self.cx+self.square_w/2-self.volume_bar_width*self.scale,
        self.cy-12*self.scale
    )

    self.volume_bar:api_w_h(self.volume_bar_width*self.scale,24*self.scale)
    self.volume_bar:api_scale(self.scale)
    self.volume_bar:update(dt)
end
function VolumeUI:draw()
    draw_round_rectangle(self.square_x,self.square_y,self.square_w,self.square_h,10)
    love.graphics.print(self.text,self.text_x,self.text_y,0,self.scale)
    self.volume_bar:draw()
end
function VolumeUI:api_scale(scale)
    self.target_scale=scale
end
function VolumeUI:api_x_y(x,y)
    self.x,self.y=x,y
end
function VolumeUI:api_cx_cy(cx,cy)
    self.cx,self.cy=cx,cy
end
function VolumeUI:api_return_width()
    return self.w
end
function VolumeUI:api_return_height()
    return self.h
end
function VolumeUI:api_value(value)
    self.value=value
    self.volume_bar:api_value(value)
end
function VolumeUI:api_update_language(text)
    self.text=text
end

-- 用于创建一个横向的选择栏的类
local ChoiceBar={}
ChoiceBar.__index=ChoiceBar
-- {float,float,table}
function ChoiceBar:new(x,y,choices)
    local init=setmetatable({},self)
    init.x=x
    init.y=y
    init.oriangle_x=x
    init.oriangle_y=y

    init.scale=1
    init.target_scale=1
    init.cx,init.cy=nil,nil

    init.index=1
    init.num=#choices
    init.choices=choices

    init.current_text=nil

    local font=love.graphics.getFont()
    init.text_length={}
    for _,t in ipairs(choices)do
        table.insert(init.text_length,font:getWidth(t))
    end

    init.call_func={
        ["keypressed"]=function(key)
            if key=="left" then
                init.index=init.index-1
            elseif key=="right" then
                init.index=init.index+1
            end
            if init.index<=1 then
                init.index=1
            elseif init.index>=init.num then
                init.index=init.num
            end
        end
    }
    return init
end
function ChoiceBar:update(dt)
    self.x=(self.oriangle_x-self.cx)*self.scale+self.cx
    self.y=(self.oriangle_y-self.cy)*self.scale+self.cy
    self.current_text=self.choices[self.index]

    if self.index==1 then
        self.current_text=" "..self.current_text..">"
    elseif self.index==self.num then
        self.current_text="<"..self.current_text.." "
    else
        self.current_text="<"..self.current_text..">"
    end
end
function ChoiceBar:draw()
    love.graphics.print(self.current_text,self.x,self.y,0,self.scale)
end
function ChoiceBar:api_scale(scale)
    self.target_scale=scale
end
function ChoiceBar:api_cx_cy(cx,cy)
    self.cx,self.cy=cx,cy
end


-- 用于创建一个左右选择的UI元素
local ChoiceUI={}
ChoiceUI.__index=ChoiceUI
function ChoiceUI:new(cx,cy,w,h,text,choices,index,func)
    local init=setmetatable({},self)

    init.scale=1
    init.target_scale=1
    init.__update_scale=create_value_trip()

    init.func=func or function() end

    init.cx=cx or 0
    init.cy=cy or 0
    init.w=w
    init.h=h
    init.x=init.cx-init.w/2
    init.y=init.cy-init.h/2

    init.square_x=init.cx-init.w/2
    init.square_y=init.cy-init.h/2
    init.square_w=init.w
    init.square_h=init.h

    init.font=love.graphics.getFont()
    init.text=text
    init.text_length=init.font:getWidth(init.text)
    init.text_x=init.x+10
    init.text_y=init.y+(init.h-30)/2

    init.choices=choices
    init.choices_num=#init.choices
    init.choices_index=index or nil
    init.choices_text=init.choices[init.choices_index]

    init.__choice_arrow_size=15
    init.__choice_arrow_h=math.sqrt(3)/2*init.__choice_arrow_size

    init.color_1={1,1,1,1}
    init.color_2={1,1,1,0.2}
    
    init.choice_right_color=init.color_1
    init.choice_right_arrow_x=nil
    init.choice_right_arrow_y=nil
    init.choice_right_arrow=nil
    init.choice_left_color=init.color_1
    init.choice_left_arrow_x=nil
    init.choice_left_arrow_y=nil
    init.choice_left_arrow=nil
    init.choicearrow_mesh=nil

    init.call_func={
        ["keypressed"]=function (key)
            if key=="left" then
                init.choices_index=init.choices_index-1
            elseif key=="right" then
                init.choices_index=init.choices_index+1
            end
            init.choices_index=math.min(init.choices_num,math.max(1,init.choices_index))
            if key=="right" or "left" then
                init.func(init.choices_index)
            end
        end
    }
    return init
end
function ChoiceUI:update(dt)
    self.scale=self.__update_scale(dt,self.scale,self.target_scale,10,0.9)
    self.square_w=self.w*self.scale
    self.square_h=self.h*self.scale
    self.square_x=self.cx-self.square_w/2
    self.square_y=self.cy-self.square_h/2
    self.text_x=self.cx-self.square_w/2+20*self.scale
    self.text_y=self.cy-15*self.scale
    self:__update_arrow()
end
function ChoiceUI:draw()
    draw_round_rectangle(self.square_x,self.square_y,self.square_w,self.square_h,10)
    love.graphics.print(self.text,self.text_x,self.text_y,0,self.scale)
    love.graphics.draw(self.choice_arrow_mesh)
    love.graphics.print(self.choices[self.choices_index],self.choice_text_x,self.choice_text_y,0,self.scale*0.8)
end
function ChoiceUI:api_scale(scale)
    self.target_scale=scale
end
function ChoiceUI:api_cx_cy(cx,cy)
    self.cx,self.cy=cx,cy
end
function ChoiceUI:api_x_y(x,y)
    self.x,self.y=x,y
end
function ChoiceUI:api_return_width()
    return self.w
end
function ChoiceUI:api_return_height()
    return self.h
end
function ChoiceUI:api_value(value)
    self.choices_index=value
end
function ChoiceUI:api_update_language(text,choices)
    self.text=text
    self.choices=choices
end
-- 更新左右箭头状态以及文本的位置信息
function ChoiceUI:__update_arrow()
    if self.choices_index==1 then
        self.choice_left_color=self.color_2
        self.choice_right_color=self.color_1
    elseif self.choices_index==self.choices_num then
        self.choice_left_color=self.color_1
        self.choice_right_color=self.color_2
    else
        self.choice_left_color=self.color_1
        self.choice_right_color=self.color_1
    end
    if self.scale<=1 then
        self.choice_left_color={0,0,0,0}
        self.choice_right_color={0,0,0,0}
    end

    local choice_length = self.font:getWidth(self.choices[self.choices_index])*self.scale*0.8
    self.choice_text_x=self.cx+self.square_w/2-choice_length-20
    self.choice_text_y=self.cy-12*self.scale
    
    self.choice_arrow_y=self.cy
    self.choice_right_arrow_x=self.cx+self.square_w/2-18
    self.choice_left_arrow_x=self.cx+self.square_w/2-choice_length-22

    self.choice_arrow = {
        {self.choice_right_arrow_x, self.choice_arrow_y - self.__choice_arrow_h/2, 0, 0,unpack(self.choice_right_color)},  -- 顶部
        {self.choice_right_arrow_x + self.__choice_arrow_size, self.choice_arrow_y, 0, 0,unpack(self.choice_right_color)},  -- 右下
        {self.choice_right_arrow_x, self.choice_arrow_y + self.__choice_arrow_h/2, 0, 0,unpack(self.choice_right_color)},   -- 底部
        {self.choice_left_arrow_x, self.choice_arrow_y - self.__choice_arrow_h/2, 0, 0,unpack(self.choice_left_color)},  -- 顶部
        {self.choice_left_arrow_x - self.__choice_arrow_size, self.choice_arrow_y, 0, 0,unpack(self.choice_left_color)},
        {self.choice_left_arrow_x, self.choice_arrow_y + self.__choice_arrow_h/2, 0, 0,unpack(self.choice_left_color)}   -- 底部
    }
    self.choice_arrow_mesh = love.graphics.newMesh(self.choice_arrow, "triangles", "dynamic")
end

-- 用于创建一个按钮元素
local ButtomUI={}
ButtomUI.__index=ButtomUI
function ButtomUI:new(cx,cy,w,h,text,func)
    local init=setmetatable({},self)
    init.font=love.graphics.getFont()
    init.text=text
    init.text_length=init.font:getWidth(init.text)
    init.func=func or function() end

    init.scale=1
    init.out_scale=1
    init.target_scale=1
    init.__update_scale=create_value_trip()
    init.active_scale=1
    init.target_active_scale=1
    init.__update_active_scale=create_value_trip()
    init.is_pressed=false

    init.cx=cx
    init.cy=cy
    init.w=w or init.text_length+30
    init.h=h
    
    init.square_x=init.cx-init.w/2
    init.square_y=init.cy-init.h/2
    init.square_w=init.w
    init.square_h=init.h

    init.text_x=init.cx-init.text_length*init.scale/2
    init.text_y=init.cy-15*init.scale

    init.call_func={
        ["keypressed"]=function (key)
            if key=="space" then
                init.target_active_scale=1.1
                init.is_pressed=true
                init.func()
            end
        end
    }
    return init
end
function ButtomUI:update(dt)
    -- self.target_scale=self.active_scale
    self.out_scale=self.__update_scale(dt,self.out_scale,self.target_scale,10,0.9)
    self.active_scale=self.__update_active_scale(dt,self.active_scale,self.target_active_scale,10,0.9)
    self.active_scale=math.max(1,math.min(1.1,self.active_scale))
    self.scale=self.out_scale*self.active_scale

    if self.active_scale>=self.target_active_scale and self.is_pressed==true then
        self.target_active_scale=1
        self.is_pressed=false
    end

    self.square_w=self.w*self.scale
    self.square_h=self.h*self.scale
    self.square_x=(self.cx-self.square_w/2)
    self.square_y=(self.cy-self.square_h/2)
    self.text_x=self.cx-self.text_length*self.scale/2
    self.text_y=self.cy-15*self.scale
end
function ButtomUI:draw()
    draw_round_rectangle(self.square_x,self.square_y,self.square_w,self.square_h,10)
    love.graphics.print(self.text,self.text_x,self.text_y,0,self.scale)
end
function ButtomUI:api_scale(scale)
    self.target_scale=scale
end
function ButtomUI:api_x_y(x,y)
    self.x,self.y=x,y
end
function ButtomUI:api_cx_cy(cx,cy)
    self.cx,self.cy=cx,cy
end
function ButtomUI:api_return_width()
    return self.w
end
function ButtomUI:api_return_height()
    return self.h
end
function ButtomUI:api_update_language(text)
    self.text=text
end

-- 创建文本框,不接受外部操作
local TextBoxUI={}
TextBoxUI.__index=TextBoxUI
function TextBoxUI:new(cx,cy,w,h,text)
    local init=setmetatable({},self)
    local font=love.graphics.getFont()
    init.scale=1.3
    init.text=text
    init.text_length=font:getWidth(init.text)*init.scale

    init.cx=cx
    init.cy=cy
    init.w=w or init.text_length+30
    init.h=h
    init.x=init.cx-init.w/2
    init.y=init.cy-init.h/2

    init.text_x=nil
    init.text_y=nil
    return  init
end
function TextBoxUI:update(dt)
    self.text_x=self.cx-self.text_length/2
    self.text_y=self.cy-15*self.scale
    self.x=self.cx-self.w/2
    self.y=self.cy-self.h/2
end
function TextBoxUI:draw()
    draw_round_rectangle(self.x,self.y,self.w,self.h,15)
    love.graphics.print(self.text,self.text_x,self.text_y,0,self.scale)
end
function TextBoxUI:api_cx_cy(cx,cy)
    self.cx=cx
    self.cy=cy
end
function TextBoxUI:api_update_language(text)
    self.text=text
end

-- 创建适用于不同设置页面的标题元素,并拥有展开动画
local TitleAniUI={}
TitleAniUI.__index=TitleAniUI
function TitleAniUI:new(cx,cy,title,length)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy
    init.title=title or "Title"
    init.title_ele=TextBoxUI:new(400,100,nil,50,init.title)
    init.length=0
    init.target_length=length or 300
    init.update_length=create_value_easeOut()
    init.isActive=false
    return init
end
function TitleAniUI:update(dt)
    self.title_ele:update(dt)
    self.length=self.update_length(dt,0,self.target_length,0.5)
    self.line_x=self.cx-self.length/2
    self.line_y=self.cy+35
end
function TitleAniUI:draw()
    self.title_ele:draw()
    love.graphics.rectangle("fill",self.line_x,self.line_y,self.length,8,4)
end
function TitleAniUI:api_update_language(text)
    self.title_ele:api_update_language(text)
end
function TitleAniUI:api_cx_cy(cx,cy)
    self.cx=cx
    self.cy=cy
    self.title_ele:api_cx_cy(self.cx,self.cy)
end

-- 用于创建一个选择界面,分配不同的ui
local ChoiceBox={}
ChoiceBox.__index=ChoiceBox
function ChoiceBox:new(cx,cy,ele_table)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy

    init.ele_table=ele_table
    init.ele_num=#init.ele_table
    init.index=1
    init.distance=10

    init.ele_call_func={}
    init.ele_draw_order={}

    init.title=title or "title"
    -- 初始化时更新元素位置
    init:__update_ele_location()

    for i=1,init.ele_num do
        table.insert(init.ele_call_func,init.ele_table[i].call_back)
    end
    init.call_func={
        ["keypressed"]=function (key)
            if key=="up" then
                init.index=init.index-1
            end
            if key=="down" then
                init.index=init.index+1
            end
            init.index=math.min(math.max(1,init.index),init.ele_num)
            init.ele_table[init.index]["call_func"]["keypressed"](key)
        end
    }
    return init
end
function ChoiceBox:update(dt)
    self.ele_draw_order={}
    local lastest_index
    for i=1,self.ele_num do
        self.ele_table[i]:update(dt)
        if self.index==i then
            self.ele_table[i]:api_scale(1.3)
        else
            self.ele_table[i]:api_scale(1)
            table.insert(self.ele_draw_order,self.ele_table[i])
        end
    end
    table.insert(self.ele_draw_order,self.ele_table[self.index])
    -- self:__update_ele_location()
end
function ChoiceBox:draw()
    for i=1,#self.ele_draw_order do
        self.ele_draw_order[i]:draw()
    end
end
function ChoiceBox:__update_ele_location()
    local delta_height=self.cy
    for i=1,self.ele_num do
        local h=self.ele_table[i]:api_return_height()
        delta_height=delta_height+h+self.distance
        -- 为不同的ele分配中心坐标
        self.ele_table[i]:api_cx_cy(self.cx,delta_height)
    end
end
function ChoiceBox:api_cx_cy(cx,cy)
    self.cx=cx
    self.cy=cy
    self:__update_ele_location()
end

-- 适用于键位绑定的元素
local RecordkeyUI={}
RecordkeyUI.__index=RecordkeyUI
function RecordkeyUI:new(cx,cy,w,h,title,default_key,font,parent,func)
    local init=setmetatable({},self)
    init.font=font or love.graphics.getFont()
    init.parent=parent or nil
    init.text=title
    init.default_key=default_key
    init.pressed_key=default_key
    init.cx=cx
    init.cy=cy
    init.w=w
    init.h=h
    init.x=init.cx-w/2
    init.y=init.cy-h/2

    init.scale=1
    init.out_scale=1
    init.target_scale=1
    
    init.active_scale=1
    init.target_active_scale=1
    init.__update_scale=create_value_trip()
    init.__update_active_scale=create_value_trip()

    init.is_self=false
    init.font_alpha=1
    init.alpha_add=0

    init.idle_color={{1,1,1,.2},{1,1,1,1}}
    init.active_color={{1,1,1,1},{1,1,1,1}}

    init.func=func or function()end

    init.call_func={
        ["keypressed"]=function(key)
            if init.is_active then
                local pressed_key=key
                init.pressed_key=init:__chnage_pressed_key(pressed_key)
                init.is_active=false
                init.parent.isActiveUI=false
                init.target_active_scale=1.1
                init.func(key)
            else
                if key=="space" then
                    init.is_active=true
                    init.pressed_key="_"
                    init.parent.isActiveUI=true
                    init.target_active_scale=1
                end
            end
        end
    }
    return init
end
function RecordkeyUI:update(dt)
    self.out_scale=self.__update_scale(dt,self.out_scale,self.target_scale,10,0.9)
    self.active_scale=self.__update_active_scale(dt,self.active_scale,self.target_active_scale,20,0.8)
    self.scale=self.out_scale*self.active_scale
    self.target_active_scale=1
    self.square_w=self.w*self.scale
    self.square_h=self.h*self.scale
    self.square_x=self.cx-self.square_w/2
    self.square_y=self.cy-self.square_h/2
    self.text_x=self.square_x+20
    self.text_y=self.cy-15*self.scale

    -- print(self.pressed_key)
    self.pressed_key=self:__chnage_pressed_key(self.pressed_key)
    self.pressed_key_x=self.cx+self.square_w/2-self.font:getWidth(self.pressed_key)-20

    if self.is_active then
        self.alpha_add=(self.alpha_add+dt)*1.1
        if self.alpha_add>=math.pi then
            self.alpha_add=0
        end
        self.font_alpha=math.abs(math.cos(self.alpha_add))
    else
        self.font_alpha=1
    end

end
function RecordkeyUI:draw()
    draw_round_rectangle(self.square_x,self.square_y,self.square_w,self.square_h,10,{1,1,1,0.2},{1,1,1,1})
    love.graphics.print(self.text,self.text_x,self.text_y)
    love.graphics.setColor(1,1,1,self.font_alpha)
    love.graphics.print(self.pressed_key,self.pressed_key_x,self.text_y)
    love.graphics.setColor(1,1,1,1)
end
function RecordkeyUI:api_cx_cy(cx,cy)
    self.cx,self.cy=cx,cy
end
function RecordkeyUI:api_scale(scale)
    self.target_scale=scale
end
function RecordkeyUI:api_return_width()
    return self.w
end
function RecordkeyUI:api_return_height()
    return self.h
end
-- 从外部更新按键
function RecordkeyUI:api_update_pressedkey(key)
    self.pressed_key=key
end
function RecordkeyUI:__chnage_pressed_key(key)
    local keys={
        ["up"]="↑",
        ["down"]="↓",
        ["left"]="←",
        ["right"]="→",
    }
    if keys[key] then
        key=keys[key]
    end
    key=string.upper(key)
    return key
end

-- 适用于键位绑定的自动管理类
local ControlBox={}
ControlBox.__index=ControlBox
function ControlBox:new(cx,cy,title,row,ele_table,ele_attribute,parent)
    local init=setmetatable({},self)
    local font=love.graphics.getFont()
    init.parent=parent or nil
    init.cx=cx
    init.cy=cy
    init.row=row or 1

    init.ele_table=ele_table
    init.ele_num=#init.ele_table

    -- ele_attribute 适用于调整自动调整元素位置, 为true, 则自动符合程序分配, 为false, 则最后排布为一列
    init.ele_attribute=ele_attribute or {}
    for i=#ele_attribute+1,init.ele_num do
        table.insert(init.ele_attribute,true)
    end

    init.auto_format_num = 0
    for i = 1, init.ele_num do
        init.auto_format_num=init.auto_format_num+(init.ele_attribute[i] and 1 or 0)
    end

    init.index=1

    init.row_distance=30
    init.line_distance=10
    init.ele_width=300
    init.ele_height=40

    init.ele_draw_order={}
    init:__update_draw_order()
    init.lines=init:__update_ele_location()
    local ele_matrix_position={1,1}
    init.call_func={
        ["keypressed"]=function(key)

            if init.parent.isActiveUI==false then
                local last_index=init.index

                if key=="up" then
                    if init.lines[ele_matrix_position[1]-1]~=nil then
                        if init.lines[ele_matrix_position[1]-1]>1 then
                            init.index=init.index-init.row
                        else
                            init.index=init.index-init.lines[ele_matrix_position[1]-1]-ele_matrix_position[2]+1
                        end
                    end
                elseif key=="down" then
                    if init.lines[ele_matrix_position[1]+1]==1 then
                        init.index=init.index+init.lines[ele_matrix_position[1]]-ele_matrix_position[2]+1
                    else
                        init.index=init.index+init.row
                    end
                end

                -- 将索引前移或后移一位
                if key=="left" then
                    init.index=init.index-1
                elseif key=="right" then
                    init.index=init.index+1
                end

                -- 将索引限定于规定范围内
                init.index=math.max(1,math.min(init.index,init.ele_num))
                -- 更新元素位置
                ele_matrix_position=init:__compute_row_and_col(init.index,init.lines)
            end
            init.ele_table[init.index].call_func["keypressed"](key)
            init:__update_draw_order()
        end
    }
    return init
end
function ControlBox:update(dt)
    for i=1,self.ele_num do
        self.ele_table[i]:update(dt)
    end
end
function ControlBox:draw()
    for i=1,self.ele_num do
        self.ele_draw_order[i]:draw()
    end
end
-- 更新位置
function ControlBox:api_cx_cy(cx,cy)
    self.cx=cx
    self.cy=cy
    self:__update_ele_location()
end
-- 更新各个元素的绘制顺序
function ControlBox:__update_draw_order()
    self.ele_draw_order={}
    self.ele_table[self.index]:api_scale(1.2)
    for i=1,self.ele_num do
        if i~=self.index then
            table.insert(self.ele_draw_order,self.ele_table[i])
            self.ele_table[i]:api_scale(1)
        end
    end
    table.insert(self.ele_draw_order,self.ele_table[self.index])
end
-- 更新各个元素的位置
function ControlBox:__update_ele_location()
    local auto_format_num=0
    for i=1,self.ele_num do
        if self.ele_attribute[i]==true then
            auto_format_num=auto_format_num+1
        end
    end

    -- 处理遵从自动定位元素的位置信息
    local last_ele_num=auto_format_num
    local lines={}
    local start_cy=self.cy

    while true do
        last_ele_num=last_ele_num-self.row
        if last_ele_num>0 then
            table.insert(lines,self.row)
        elseif last_ele_num<=0 then
            table.insert(lines,last_ele_num+self.row)
            break
        end
    end

    local ele_positions={}
    for i,l in ipairs(lines)do
        local ele_cy=start_cy+(self.ele_height+self.line_distance)*(i-1)+self.ele_height/2
        local ele_cx_es=self:__update_line_cx(l,self.cx,self.ele_width,self.row_distance)
        for e=1,l do
            table.insert(ele_positions,{ele_cx_es[e],ele_cy})
        end
    end

    -- 处理不遵从列的分布的元素的位置信息
    for i=1,self.ele_num-auto_format_num do
        local ele_cy=start_cy+(self.ele_height+self.line_distance)*(#lines+i-1)+self.ele_height/2
        local ele_cx=self.cx
        table.insert(ele_positions,{ele_cx,ele_cy})
    end

    for i=1,self.ele_num-auto_format_num do
        table.insert(lines,1)
    end

    for i=1,self.ele_num do
        self.ele_table[i]:api_cx_cy(unpack(ele_positions[i]))
    end
    -- 返回每行的元素数
    return lines
end
-- 计算某一行中各个元素的中心cx的位置
function ControlBox:__update_line_cx(line_num,cx,width,distance)
    local distance=distance or 10
    local start_x=cx-width*line_num/2-distance*(line_num-1)/2
    local ele_cx_table={}
    for i=1,line_num do
        local ele_cx=start_x+(width+distance)*(i-1)+width/2
        table.insert(ele_cx_table,ele_cx)
    end
    return ele_cx_table
end
-- 计算init.index位于init.lines的行数
function ControlBox:__compute_row_and_col(index,lines)
    local row=1
    local col=0
    local num=0
    local index=index

    for i,n in ipairs(lines)do
        local last_index=index
        index=index-n
        if index<=0 then
            col=last_index
            break
        end
        row=row+1
    end
    return {row,col}
end

-- 声音设置相关的界面
local VolumeMenu={}
VolumeMenu.__index=VolumeMenu
function VolumeMenu:new(cx,cy,parent)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy
    init.parent=parent
    init.title_ani=TitleAniUI:new(init.cx,init.cy,init.parent.setting_language["volume"]["title"],500)
    -- 前面三个为音量调节
    init.ele_set={
            VolumeUI:new(0,0,500,40,
                init.parent.setting_language["volume"]["options"]["master_volume"]["title"],
                init.parent.setting["volume"]["options"]["master_volume"]["value"],
                function(value)
                    init.parent.setting["volume"]["options"]["master_volume"]["value"]=value
                end),
            VolumeUI:new(0,0,500,40,
                init.parent.setting_language["volume"]["options"]["music_volume"]["title"],
                init.parent.setting["volume"]["options"]["music_volume"]["value"],
                function(value)
                    init.parent.setting["volume"]["options"]["music_volume"]["value"]=value
                end),
            VolumeUI:new(0,0,500,40,
                init.parent.setting_language["volume"]["options"]["sfx_volume"]["title"],
                init.parent.setting["volume"]["options"]["sfx_volume"]["value"],
                function(value)
                    init.parent.setting["volume"]["options"]["sfx_volume"]["value"]=value
                end),
            ButtomUI:new(0,0,300,40,init.parent.setting_language["volume"]["options"]["default"]["title"],
                function ()
                    for i,n in pairs(init.parent.setting["volume"]["options"])do
                        if n["value"]then
                            n["value"]=n["default_value"]
                        end
                    end
                    init:__update_value()
                end),
            ButtomUI:new(0,0,300,40,
                init.parent.setting_language["volume"]["options"]["yes"]["title"],    
                function() 
                    init.parent:api_mode("setting")
                    init.parent:api_save_setting(init.parent.setting)
                end)
    }

    init.volume_menu=ChoiceBox:new(
        init.cx,init.cy+25,
        {unpack(init.ele_set)}
    )
    init.call_func={
        ["keypressed"]=function(key)
            init.volume_menu.call_func["keypressed"](key)
            -- init:__update_value()
        end,
        ["update_location"]=function (cx,cy)
            init.title_ani:api_cx_cy(cx,cy)
            init.volume_menu:api_cx_cy(cx,cy+25)
        end
    }
    return init
end
function VolumeMenu:update(dt)
    self.title_ani:update(dt)
    self.volume_menu:update(dt)
end
function VolumeMenu:draw()
    self.title_ani:draw()
    self.volume_menu:draw()
end
function VolumeMenu:__update_value()
    local volume_options={"master_volume","music_volume","sfx_volume"}
    for i=1,3 do
        self.ele_set[i]:api_value(self.parent.setting["volume"]["options"][volume_options[i]]["value"])
    end
end

-- 图形设置相关的界面
local GraphicsMenu={}
GraphicsMenu.__index=GraphicsMenu
function GraphicsMenu:new(cx,cy,parent)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy
    init.parent=parent
    init.title_ani=TitleAniUI:new(init.cx,init.cy,init.parent.setting_language["graphics"]["title"],450)

    init.ele_title={"resolution","window_mode","vsync"}
    init.ele_set={
        ChoiceUI:new(0,0,450,40,
            init.parent.setting_language["graphics"]["options"]["resolution"]["title"],
            init.parent.setting_language["graphics"]["options"]["resolution"]["choices"],
            init.parent.setting["graphics"]["options"]["resolution"]["value"],
            function(value)
                init.parent.setting["graphics"]["options"]["resolution"]["value"]=value
            end
            ),
        ChoiceUI:new(0,0,450,40,
            init.parent.setting_language["graphics"]["options"]["window_mode"]["title"],
            init.parent.setting_language["graphics"]["options"]["window_mode"]["choices"],
            init.parent.setting["graphics"]["options"]["window_mode"]["value"],
            function(value)
                init.parent.setting["graphics"]["options"]["window_mode"]["value"]=value
            end),
        ChoiceUI:new(0,0,450,40,
            init.parent.setting_language["graphics"]["options"]["vsync"]["title"],
            init.parent.setting_language["graphics"]["options"]["vsync"]["choices"],
            init.parent.setting["graphics"]["options"]["vsync"]["value"],
            function(value)
                init.parent.setting["graphics"]["options"]["vsync"]["value"]=value
            end),
        ButtomUI:new(0,0,300,40,init.parent.setting_language["graphics"]["options"]["default"]["title"],
            function ()
                for i=1,3 do
                    -- print(init.parent.setting["graphics"]["options"][init.ele_title[i]]["value"])
                    init.parent.setting["graphics"]["options"][init.ele_title[i]]["value"]=
                    init.parent.setting["graphics"]["options"][init.ele_title[i]]["default_value"]
                end
                init:__update_value()
            end
        ),
        ButtomUI:new(0,0,300,40,
            init.parent.setting_language["graphics"]["options"]["yes"]["title"],
            function() 
                init.parent:api_mode("setting")
                init.parent:api_save_setting(init.parent.setting)
            end)
    }
    init.graphics_menu=ChoiceBox:new(
        init.cx,init.cy+25,
        {unpack(init.ele_set)}
    )
    init.call_func={
        ["keypressed"]=function(key)
            init.graphics_menu.call_func["keypressed"](key)
        end,
        ["update_location"]=function(cx,cy)
            init.title_ani:api_cx_cy(cx,cy)
            init.graphics_menu:api_cx_cy(cx,cy+25)
        end
    }
    return init
end
function GraphicsMenu:update(dt)
    self.title_ani:update(dt)
    self.graphics_menu:update(dt)
end
function GraphicsMenu:draw()
    self.title_ani:draw()
    self.graphics_menu:draw()
end
function GraphicsMenu:__update_value()
    for i=1,3 do
        self.ele_set[i]:api_value(self.parent.setting["graphics"]["options"][self.ele_title[i]]["default_value"])
    end
end

-- 游戏设置相关的界面
local GameMenu={}
GameMenu.__index=GameMenu
function GameMenu:new(cx,cy,parent)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy
    init.parent=parent
    init.title_ele=TitleAniUI:new(init.cx,init.cy,init.parent.setting_language["game"]["title"],450)
    init.ele_title={"language"}
    init.ele_set={
        ChoiceUI:new(0,0,450,40,
            init.parent.setting_language["game"]["options"]["language"]["title"],
            init.parent.setting_language["game"]["options"]["language"]["choices"],
            init.parent.setting["game"]["options"]["language"]["value"],
            function (value)
                init.parent.setting["game"]["options"]["language"]["value"]=value
                init.parent:api_update_language(value)
            end),
        ButtomUI:new(0,0,300,40,
            init.parent.setting_language["game"]["options"]["default"]["title"],
            function ()
                for i=1,1 do
                    init.parent.setting["game"]["options"][init.ele_title[i]]["value"]=
                    init.parent.setting["game"]["options"][init.ele_title[i]]["default_value"]
                end
                -- 默认启用后对
                init.parent:api_update_language(init.parent.setting["game"]["options"]["language"]["value"])
                init:__update_value()
            end),
        ButtomUI:new(0,0,300,40,
            init.parent.setting_language["game"]["options"]["yes"]["title"],
            function()
                init.parent:api_mode("setting")
                init.parent:api_save_setting(init.parent.setting)
            end)
    }

    init.game_menu=ChoiceBox:new(
        init.cx,init.cy+25,
        {unpack(init.ele_set)}
    )
    init.call_func={
        ["keypressed"]=function (key)
            init.game_menu.call_func["keypressed"](key)
        end,
        ["update_location"]=function (cx,cy)
            init.title_ele:api_cx_cy(cx,cy)
            init.game_menu:api_cx_cy(cx,cy+25)
        end
    }
    return init
end
function GameMenu:update(dt)
    self.title_ele:update(dt)
    self.game_menu:update(dt)
end
function GameMenu:draw()
    self.title_ele:draw()
    self.game_menu:draw()
end
function GameMenu:__update_value()
    for i=1,#self.ele_title do
        self.ele_set[i]:api_value(self.parent.setting["game"]["options"][self.ele_title[i]]["default_value"])
    end
end

-- 键位控制界面
local ControlMenu={}
ControlMenu.__index=ControlMenu
function ControlMenu:new(cx,cy,parent)
    local init=setmetatable({},self)
    local font=love.graphics.getFont()
    init.isActiveUI=false
    init.parent=parent or nil
    init.cx=cx
    init.cy=cy
    init.title=init.parent.setting_language["control"]["title"]
    init.title_ele=TitleAniUI:new(init.cx,init.cy,init.title,630)
    init.options_set={"up","down","left","right","shoot","skill","slow"}
    -- 前7个为记录按键的元素,后两个为按钮ui
    init.ele_set={
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["up"]["title"],
            init.parent.setting["control"]["options"]["up"]["value"],
            font,init,
            function (pressed_key)
                init.parent.setting["control"]["options"]["up"]["value"]=pressed_key
                init:update_keys("up")
            end),
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["down"]["title"],
            init.parent.setting["control"]["options"]["down"]["value"],
            font,init,
            function (pressed_key)
                init.parent.setting["control"]["options"]["down"]["value"]=pressed_key
                init:update_keys("down")
            end),
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["left"]["title"],
            init.parent.setting["control"]["options"]["left"]["value"],
            font,init,
            function (pressed_key)
                init.parent.setting["control"]["options"]["left"]["value"]=pressed_key
                init:update_keys("left")
            end),
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["right"]["title"],
            init.parent.setting["control"]["options"]["right"]["value"],
            font,init,                
            function (pressed_key)
                init.parent.setting["control"]["options"]["right"]["value"]=pressed_key
                init:update_keys("right")
            end),
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["shoot"]["title"],
            init.parent.setting["control"]["options"]["shoot"]["value"],
            font,init,
            function (pressed_key)
                init.parent.setting["control"]["options"]["shoot"]["value"]=pressed_key
                init:update_keys("shoot")
            end),
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["skill"]["title"],
            init.parent.setting["control"]["options"]["skill"]["value"],
            font,init,
            function (pressed_key)
                init.parent.setting["control"]["options"]["skill"]["value"]=pressed_key
                init:update_keys("skill")
            end),
        RecordkeyUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["slow"]["title"],
            init.parent.setting["control"]["options"]["slow"]["value"],
            font,init,
            function (pressed_key)
                init.parent.setting["control"]["options"]["slow"]["value"]=pressed_key
                init:update_keys("slow")
            end),
        ButtomUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["default"]["title"],
            function()
                for i,n in pairs(init.parent.setting["control"]["options"])do
                    if n["value"] then
                        n["value"]=n["default_value"]
                        init:__update_record_ui_pressedkey()
                    end
                end
            end),
        ButtomUI:new(0,0,300,40,
            init.parent.setting_language["control"]["options"]["yes"]["title"],
            function()
                init.parent:api_mode("setting") 
                init.parent:api_save_setting(init.parent.setting)
            end),
    }
    init.control_menu=ControlBox:new(
        cx,init.cy+55,init.title,2,
        {
            unpack(init.ele_set),
        },
        {true,true,true,true,true,true,true,false,false},
        init
    )
    init.call_func={
        ["keypressed"]=function (key)
            init.control_menu.call_func["keypressed"](key)
        end,
        ["update_location"]=function(cx,cy)
            init.title_ele:api_cx_cy(cx,cy)
            init.control_menu:api_cx_cy(cx,cy+55)
        end
    }
    return init
end
function ControlMenu:update(dt)
    self.title_ele:update(dt)
    self.control_menu:update(dt)
end
function ControlMenu:draw()
    self.title_ele:draw()
    self.control_menu:draw()
end
function ControlMenu:api_cx_cy(cx,cy)
    self.cx=cx
    self.cy=cy
end
function ControlMenu:resize(x,y)
end
function ControlMenu:__update_record_ui_pressedkey()
    for i=1,7 do
        self.ele_set[i]:api_update_pressedkey(string.upper(self.parent.setting["control"]["options"][self.options_set[i]]["default_value"]))
    end
end
-- 检查与更新pressed_key, 防止键位冲突
function ControlMenu:update_keys(name)
    local key=self.parent.setting["control"]["options"][name]["value"]
    
    for i,n in ipairs(self.options_set) do
        if n~=name then
            local current_key=self.parent.setting["control"]["options"][n]["value"]
            if current_key==key then
                if self.parent.setting["control"]["options"][n]["value"]==self.parent.setting["control"]["options"][n]["default_value"] then
                    self.parent.setting["control"]["options"][n]["value"]=self.parent.setting["control"]["options"][name]["default_value"]
                else
                    self.parent.setting["control"]["options"][n]["value"]=self.parent.setting["control"]["options"][n]["default_value"]
                end
                self.ele_set[i]:api_update_pressedkey(self.parent.setting["control"]["options"][n]["value"])
            end 
        end
    end
end

-- 设置页面的主菜单
local SettingMenu={}
SettingMenu.__index=SettingMenu
function SettingMenu:new(cx,cy,parent)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy
    init.parent=parent
    init.title_ele=TitleAniUI:new(init.cx,init.cy,init.parent.setting_language["setting"]["title"],300)
    init.timer=0
    init.setting_menu=ChoiceBox:new(
        init.cx,init.cy+25,
        {
            ButtomUI:new(0,0,300,40,init.parent.setting_language["setting"]["game"],function() init.parent:api_mode("game") end),
            ButtomUI:new(0,0,300,40,init.parent.setting_language["setting"]["volume"],function() init.parent:api_mode("volume") end),
            ButtomUI:new(0,0,300,40,init.parent.setting_language["setting"]["graphics"],function() init.parent:api_mode("graphics") end),
            ButtomUI:new(0,0,300,40,init.parent.setting_language["setting"]["control"],function() init.parent:api_mode("control") end),
            ButtomUI:new(0,0,300,40,init.parent.setting_language["setting"]["quit"])
        }
    )
    init.call_func={
        ["keypressed"]=function(key)
            init.setting_menu.call_func["keypressed"](key)
        end,
        ["update_location"]=function(cx,cy)
            init.title_ele:api_cx_cy(cx,cy)
            init.setting_menu:api_cx_cy(cx,cy+25)
        end
    }
    return init
end
function SettingMenu:update(dt)
    self.title_ele:update(dt)
    self.setting_menu:update(dt)
    self.timer=self.timer+dt
    self.timer=math.min(0.1,self.timer)
end
function SettingMenu:draw()
    self.title_ele:draw()
    self.setting_menu:draw()
end

-- 设置模块,用于调控所有的设置界面
local SettingMode={}
SettingMode.__index=SettingMode
function SettingMode:new(cx,cy)
    local init=setmetatable({},self)
    init.cx=cx
    init.cy=cy

    -- 用于构建语言文件路径, 勿动
    local setting_language={"english","chinese"}
    -- init.setting=require("setting")
    init.file_io=FileIO:new()
    init.setting=init:load_custom_setting()
    init:init_api_update_language(init.setting["game"]["options"]["language"]["value"])
    init.game=init.setting.game
    init.menus={
        setting  = function() return SettingMenu:new(init.cx,init.cy,init) end,
        game     = function() return GameMenu:new(init.cx, init.cy, init) end,
        volume   = function() return VolumeMenu:new(init.cx, init.cy, init) end,
        graphics = function() return GraphicsMenu:new(init.cx, init.cy, init) end,
        control  = function() return ControlMenu:new(init.cx, init.cy, init) end
    }
    init.mode="setting"
    init.current_menu=init.menus[init.mode]()
    init.call_func={
        ["keypressed"]=function(key)
            init.current_menu.call_func["keypressed"](key)
            if key=="escape" then
                -- init.current_menu=init.menus["setting"]()
                -- init:api_save_setting(init.setting)
            end
        end
    }
    return init
end
function SettingMode:update(dt)
    self.current_menu:update(dt)
end
function SettingMode:draw()
    self.current_menu:draw()
end
function SettingMode:update_location(cx,cy)
    if self.current_menu.call_func["update_location"] then
        self.current_menu.call_func["update_location"](cx,cy)
    end
end

function SettingMode:api_mode(mode)
    self.mode=mode
    self.current_menu=self.menus[mode]()
    self:update_location(self.cx,self.cy)
end
function SettingMode:api_cx_cy(cx,cy)
    self.cx=cx
    self.cy=cy
end
-- 更新保存在appdata中的设置文件
function SettingMode:api_save_setting(setting)
    self.file_io:save_setting(setting,"setting.lua")
end
-- 用于更新语言数据
function SettingMode:init_api_update_language(lang_index)
    local language_choices={"english","chinese"}
    self.setting_language=require("language/"..language_choices[lang_index].."/setting")
end
function SettingMode:api_update_language(lang_index)
    local language_choices={"english","chinese"}
    self.setting_language=require("language/"..language_choices[lang_index].."/setting")
end
-- 加载自定义的用户配置文件
function SettingMode:load_custom_setting()
    local content,size=love.filesystem.read("setting.lua")
    -- print("Save directory:", love.filesystem.getSaveDirectory())
    if not content then
        local setting=require("oriangle_setting")
        self.file_io:save_setting(setting,"setting.lua")
        return setting
    end
    local chunk,err=load(content)
    if not chunk then
    end
    return chunk()
end


-- 创建一个矩形的颜色渐变mesh(顺时针方向,左上开始)
local GradientMesh = {}
GradientMesh.__index = GradientMesh
-- 构造函数：传入四角颜色
function GradientMesh:new(c1, c2, c3, c4)
    local init= setmetatable({}, self)
    init.c1 = c1 or {0.6, 0.2, 0.8, 1}
    init.c2 = c2 or {0.2, 0.4, 1.0, 1}
    init.c3 = c3 or {1.0, 0.5, 0.2, 1}
    init.c4 = c4 or {1.0, 0.0, 0.0, 1}
    init.mesh = nil
    init:resize(love.graphics.getWidth(), love.graphics.getHeight())
    return init
end
function GradientMesh:update(dt)
    self.t=self.t+dt*3
    self.c1 = {math.sin(self.t*0.8)*0.5+0.5, 0.2, 0.8, 1}
    self.c2 = {0.2, math.sin(self.t*0.6)*0.5+0.5, 1.0, 1}
    self.c3 = {1.0, 0.5, math.sin(self.t*0.9)*0.5+0.5, 1}
    self.c4 = {1.0, math.sin(self.t*0.7)*0.5+0.5, 0.0, 1}
    local c={self.c1,self.c2,self.c3,self.c4}
    for i=1,4 do
        local v={self.mesh:getVertex(i)}
        v[5],v[6],v[7],v[8]=unpack(c[i])
        self.mesh:setVertex(i,v)
    end
end
function GradientMesh:draw()
    love.graphics.draw(self.mesh)
end
function GradientMesh:resize(w, h)
    -- 定义四个顶点，按顺时针顺序
    local vertices = {
        {0,   0,   0, 0, unpack(self.c1)},  -- 左上
        {w,   0,   1, 0, unpack(self.c2)},  -- 右上
        {w,   h,   1, 1, unpack(self.c3)},  -- 右下
        {0,   h,   0, 1, unpack(self.c4)},  -- 左下
    }
    self.mesh=love.graphics.newMesh(vertices, "fan", "dynamic")
    self.t=0
end


-- main
local test
local mesh
local file_io

local result
function love.load()
    love.window.setMode(800, 600, {resizable=true})
    local font=love.graphics.newFont("font/AiDianFengYaHei.ttf",30)
    love.graphics.setFont(font)
    love.graphics.setLineWidth(3)

    test=SettingMode:new(400,100)
    mesh=GradientMesh:new()
end

function love.update(dt)
    test:update(dt)
    mesh:update(dt)
end

function love.draw()
    mesh:draw()
    test:draw()
end

function love.keypressed(key)
    test.call_func["keypressed"](key)
end
function love.resize()
    local w=love.graphics.getWidth()
    local h=love.graphics.getHeight()
    local cx=math.floor(w/2)
    local cy=math.floor(100*(h/600))
    mesh:resize(w,h)
    test:update_location(cx,cy)
    test:api_cx_cy(cx,cy)
end