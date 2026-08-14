-- Extra Items Bar - lightweight native event dispatcher.
-- Replaces AceEvent-3.0, which the original module only used as a
-- RegisterEvent/UnregisterEvent facade. See NOTICE.txt for attribution.

local EIB = _G.EIB

local frame = CreateFrame("Frame")
frame.registrations = {}

frame:SetScript("OnEvent", function(_, event, ...)
	local list = frame.registrations[event]
	if not list then
		return
	end

	for _, registration in pairs(list) do
		local object, handler = registration[1], registration[2]
		local func = object[handler]
		if func then
			func(object, ...)
		end
	end
end)

---Register a frame event. handler is a method name (string); if omitted it
---defaults to a method named after the event (AceEvent semantics).
---@param event string the frame event to listen to
---@param handler string? method name on this module
function EIB:RegisterEvent(event, handler)
	if not event then
		return
	end

	if type(handler) ~= "string" then
		handler = event
	end

	local registrations = frame.registrations
	if not registrations[event] then
		registrations[event] = {}
		frame:RegisterEvent(event)
	end

	-- Avoid double-registering the same object+handler on the same event
	for _, registration in pairs(registrations[event]) do
		if registration[1] == self and registration[2] == handler then
			return
		end
	end

	tinsert(registrations[event], { self, handler })
end

---Unregister a frame event for this module.
---@param event string the frame event to stop listening to
function EIB:UnregisterEvent(event)
	local registrations = frame.registrations[event]
	if not registrations then
		return
	end

	local remaining = {}
	local found = false
	for _, registration in pairs(registrations) do
		if registration[1] == self then
			found = true
		else
			tinsert(remaining, registration)
		end
	end

	if found then
		registrations[event] = remaining
		if #remaining == 0 then
			frame:UnregisterEvent(event)
		end
	end
end