Account = {
    balance = 0,
}
    
function Account:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Account:deposit (v)
    self.balance = self.balance + v
end

function Account:withdraw (v)
    if v > self.balance then error"insufficient funds" end
    self.balance = self.balance - v
end

SpecialAccount = Account:new{
    limit = 0,
}

function SpecialAccount:withdraw (v)
    if v - self.balance >= self:getLimit() then
      error("insufficient funds")
    end
    
    self.balance = self.balance - v
end

function SpecialAccount:getLimit ()
    return self.limit
end

s = SpecialAccount:new{limit = 1000}

s:deposit(100)
s:withdraw(1000)
s:withdraw(1000)
