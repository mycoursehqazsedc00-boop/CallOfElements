--[[

	CALL OF ELEMENTS
	Totem Twisting Module, Menu UI & Minimap Button
	Strict Lua 5.0 (Vanilla-safe with optional Client Mod acceleration)

]]

if( not COE_Twist ) then
	COE_Twist = {};
end

-- Client mod detection flags (refreshed on PLAYER_LOGIN)
local HAS_NP = false;
local HAS_SWOW = false;
local HAS_XP3 = false;

-- Spell name constants (English fallback; matched against player spellbook)
local SPELL_WINDFURY = "Windfury Totem";
local SPELL_GRACE_OF_AIR = "Grace of Air Totem";
local SPELL_TRANQUIL_AIR = "Tranquil Air Totem";

local SECONDARY_OPTIONS = {
	SPELL_GRACE_OF_AIR,
	SPELL_TRANQUIL_AIR
};

-- Runtime state
COE_Twist.LastWFTime = 0;
COE_Twist.LastSecondaryTime = 0;
COE_Twist.LastConfirmTime = 0;
COE_Twist.LastConfirmedSpell = nil;
COE_Twist.NeedSecondary = false;
COE_Twist.AlertedRefresh = false;
COE_Twist.LastAutoCastAttempt = 0;
COE_Twist.UpdateTime = 0;
COE_Twist.UpdateInterval = 0.05;
COE_Twist.PlayerGUID = nil;
COE_Twist.WFSpellID = nil;
COE_Twist.SecondarySpellIDs = {};

local function GetTwistDB()
	if( not COE_Saved ) then
		COE_Saved = {};
	end
	if( type( COE_Saved.Twist ) ~= "table" ) then
		COE_Saved.Twist = {
			AutoTwist = false,
			CombatOnly = true,
			ManualAlert = true,
			RefreshTime = 9.0,
			SecondaryTotem = SPELL_GRACE_OF_AIR,
			MinimapAngle = 225,
			ShowMinimap = true
		};
	end
	local db = COE_Saved.Twist;
	if( db.AutoTwist == nil ) then db.AutoTwist = false; end
	if( db.CombatOnly == nil ) then db.CombatOnly = true; end
	if( db.ManualAlert == nil ) then db.ManualAlert = true; end
	if( not db.RefreshTime ) then db.RefreshTime = 9.0; end
	if( not db.SecondaryTotem ) then db.SecondaryTotem = SPELL_GRACE_OF_AIR; end
	if( not db.MinimapAngle ) then db.MinimapAngle = 225; end
	if( db.ShowMinimap == nil ) then db.ShowMinimap = true; end
	return db;
end

function COE_Twist:DetectMods()
	HAS_NP = (type( GetNampowerVersion ) == "function");
	HAS_SWOW = (SUPERWOW_VERSION ~= nil);
	HAS_XP3 = pcall( UnitXP, "nop", "nop" );

	if( HAS_SWOW ) then
		local _, guid = UnitExists( "player" );
		COE_Twist.PlayerGUID = guid;
	elseif( HAS_NP and type( GetUnitGUID ) == "function" ) then
		COE_Twist.PlayerGUID = GetUnitGUID( "player" );
	end
end

function COE_Twist:RefreshSpellIDs()
	COE_Twist.WFSpellID = nil;
	COE_Twist.SecondarySpellIDs = {};

	local i = 1;
	while true do
		local spellName = GetSpellName( i, BOOKTYPE_SPELL );
		if( not spellName ) then
			break;
		end
		if( spellName == SPELL_WINDFURY ) then
			COE_Twist.WFSpellID = i;
		elseif( spellName == SPELL_GRACE_OF_AIR or spellName == SPELL_TRANQUIL_AIR ) then
			COE_Twist.SecondarySpellIDs[spellName] = i;
		end
		i = i + 1;
	end
end

function COE_Twist:Init()
	if( not COE or not COE.Initialized ) then
		return;
	end

	this:RegisterEvent( "PLAYER_LOGIN" );
	this:RegisterEvent( "PLAYER_ENTERING_WORLD" );
	this:RegisterEvent( "LEARNED_SPELL_IN_TAB" );
	this:RegisterEvent( "PLAYER_DEAD" );

	-- Hook COE_Totem:ActivatePendingTotem for Vanilla fallback detection
	if( COE_Totem and COE_Totem.ActivatePendingTotem and not COE_Twist.HookedActivate ) then
		local origActivate = COE_Totem.ActivatePendingTotem;
		COE_Totem.ActivatePendingTotem = function( self, totem )
			origActivate( self, totem );
			if( totem and totem.SpellName ) then
				COE_Twist:OnTotemCastConfirmed( totem.SpellName );
			end
		end
		COE_Twist.HookedActivate = true;
	end

	-- Allow Escape to close the Twist Menu
	if( UISpecialFrames ) then
		table.insert( UISpecialFrames, "COE_TwistFrame" );
	end
end

function COE_Twist:OnEvent( event )
	if( event == "PLAYER_LOGIN" ) then
		COE_Twist:DetectMods();
		COE_Twist:RefreshSpellIDs();
		COE_Twist:UpdateMinimapPosition();
		COE_Twist:RefreshUI();

		if( HAS_NP ) then
			this:RegisterEvent( "SPELL_GO_SELF" );
		end
		if( HAS_SWOW ) then
			this:RegisterEvent( "UNIT_CASTEVENT" );
		end
	elseif( event == "PLAYER_ENTERING_WORLD" or event == "LEARNED_SPELL_IN_TAB" ) then
		COE_Twist:RefreshSpellIDs();
		COE_Twist:UpdateMinimapPosition();
		COE_Twist:RefreshUI();
	elseif( event == "PLAYER_DEAD" ) then
		COE_Twist.LastWFTime = 0;
		COE_Twist.NeedSecondary = false;
		COE_Twist.AlertedRefresh = false;
		COE_Twist:RefreshUI();
	elseif( event == "SPELL_GO_SELF" ) then
		-- Nampower: arg1 is spellId
		if( HAS_NP and arg1 and type( GetSpellNameAndRankForId ) == "function" ) then
			local spellName = GetSpellNameAndRankForId( arg1 );
			if( spellName ) then
				COE_Twist:OnTotemCastConfirmed( spellName );
			end
		end
	elseif( event == "UNIT_CASTEVENT" ) then
		-- SuperWoW: arg1=casterGUID, arg3="CAST", arg4=spellId
		if( HAS_SWOW and arg3 == "CAST" and arg1 == COE_Twist.PlayerGUID and arg4 and type( SpellInfo ) == "function" ) then
			local spellName = SpellInfo( arg4 );
			if( spellName ) then
				COE_Twist:OnTotemCastConfirmed( spellName );
			end
		end
	end
end

function COE_Twist:OnTotemCastConfirmed( spellName )
	local now = GetTime();
	if( COE_Twist.LastConfirmedSpell == spellName and (now - COE_Twist.LastConfirmTime) < 0.25 ) then
		return;
	end
	COE_Twist.LastConfirmedSpell = spellName;
	COE_Twist.LastConfirmTime = now;

	local db = GetTwistDB();
	if( spellName == SPELL_WINDFURY ) then
		COE_Twist.LastWFTime = now;
		COE_Twist.NeedSecondary = true;
		COE_Twist.AlertedRefresh = false;
		if( db.ManualAlert and not db.AutoTwist ) then
			COE:Notification( "Twist -> " .. db.SecondaryTotem .. "!", COECOL_TOTEMCLEANSING );
		end
		COE_Twist:RefreshUI();
	elseif( spellName == db.SecondaryTotem or spellName == SPELL_GRACE_OF_AIR or spellName == SPELL_TRANQUIL_AIR ) then
		COE_Twist.LastSecondaryTime = now;
		COE_Twist.NeedSecondary = false;
		COE_Twist:RefreshUI();
	end
end

function COE_Twist:GetRemainingWF()
	if( COE_Twist.LastWFTime <= 0 ) then
		return 0;
	end
	local db = GetTwistDB();
	local rem = db.RefreshTime - (GetTime() - COE_Twist.LastWFTime);
	if( rem < 0 ) then
		return 0;
	end
	return rem;
end

function COE_Twist:GetNextSpell( isAuto )
	local db = GetTwistDB();
	local rem = COE_Twist:GetRemainingWF();

	if( rem <= 0 ) then
		return SPELL_WINDFURY, COE_Twist.WFSpellID;
	end

	if( COE_Twist.NeedSecondary ) then
		local secName = db.SecondaryTotem;
		local secID = COE_Twist.SecondarySpellIDs[secName];
		if( not secID ) then
			secName = SPELL_GRACE_OF_AIR;
			secID = COE_Twist.SecondarySpellIDs[secName];
		end
		if( secID ) then
			return secName, secID;
		end
	end

	-- For manual button/slash press when both totems are already down,
	-- start a fresh Windfury cycle on demand.
	if( not isAuto ) then
		return SPELL_WINDFURY, COE_Twist.WFSpellID;
	end

	return nil, nil;
end

function COE_Twist:CanCastTotem( spellID )
	if( not spellID ) then
		return false;
	end
	if( UnitIsDeadOrGhost( "player" ) or SpellIsTargeting() ) then
		return false;
	end
	if( HAS_NP and type( GetCastInfo ) == "function" ) then
		local castInfo = GetCastInfo();
		if( castInfo and castInfo.spellId and castInfo.spellId ~= 0 ) then
			return false;
		end
	end
	local start, duration = GetSpellCooldown( spellID, BOOKTYPE_SPELL );
	if( start and duration and (start > 0 or duration > 0) ) then
		return false;
	end
	return true;
end

function COE_Twist:CastTwistSpell( spellName, spellID )
	if( not COE_Twist:CanCastTotem( spellID ) ) then
		return false;
	end
	CastSpellByName( spellName );
	-- If neither Nampower nor SuperWoW is active and COE timers are disabled,
	-- optimistically advance state so manual /coe twist stays responsive.
	if( not HAS_NP and not HAS_SWOW and COE_Config and COE_Config:GetSaved( COEOPT_ENABLETIMERS ) == 0 ) then
		COE_Twist:OnTotemCastConfirmed( spellName );
	end
	return true;
end

function COE_Twist:TwistNow()
	if( not COE or not COE.Initialized ) then
		return;
	end
	if( not COE_Twist.WFSpellID ) then
		COE_Twist:RefreshSpellIDs();
	end
	local spellName, spellID = COE_Twist:GetNextSpell( false );
	if( not spellName or not spellID ) then
		COE:Message( "Windfury Totem is not learned yet." );
		return;
	end
	COE_Twist:CastTwistSpell( spellName, spellID );
end

function COE_Twist:OnUpdate( elapsed )
	COE_Twist.UpdateTime = COE_Twist.UpdateTime + elapsed;
	if( COE_Twist.UpdateTime < COE_Twist.UpdateInterval ) then
		return;
	end
	COE_Twist.UpdateTime = 0;

	local db = GetTwistDB();
	local rem = COE_Twist:GetRemainingWF();

	-- Manual Twist Alert when Windfury is about to expire
	if( db.ManualAlert and not db.AutoTwist and COE_Twist.LastWFTime > 0 ) then
		if( rem > 0 and rem <= 1.5 and not COE_Twist.AlertedRefresh ) then
			COE_Twist.AlertedRefresh = true;
			COE:Notification( "Recast Windfury Totem!", COECOL_TOTEMWARNING );
			if( HAS_XP3 ) then
				pcall( UnitXP, "notify", "taskbarIcon" );
			end
			PlaySound( "igQuestListOpen" );
		end
	end

	-- Auto Totem Twisting
	if( db.AutoTwist and COE_Twist.WFSpellID ) then
		if( not db.CombatOnly or UnitAffectingCombat( "player" ) ) then
			local now = GetTime();
			if( (now - COE_Twist.LastAutoCastAttempt) >= 0.25 ) then
				local spellName, spellID = COE_Twist:GetNextSpell( true );
				if( spellName and spellID ) then
					if( COE_Twist:CastTwistSpell( spellName, spellID ) ) then
						COE_Twist.LastAutoCastAttempt = now;
					end
				end
			end
		end
	end

	if( COE_TwistFrame and COE_TwistFrame:IsVisible() ) then
		COE_Twist:UpdateLiveStatus();
	end
end

function COE_Twist:ToggleAutoTwist()
	local db = GetTwistDB();
	db.AutoTwist = not db.AutoTwist;
	COE:Message( "Auto Totem Twisting: " .. (db.AutoTwist and "ON" or "OFF") );
	COE_Twist:RefreshUI();
end

function COE_Twist:ToggleManualAlert()
	local db = GetTwistDB();
	db.ManualAlert = not db.ManualAlert;
	COE:Message( "Manual Twist Alerts: " .. (db.ManualAlert and "ON" or "OFF") );
	COE_Twist:RefreshUI();
end

function COE_Twist:CycleSecondaryTotem()
	local db = GetTwistDB();
	if( db.SecondaryTotem == SPELL_GRACE_OF_AIR ) then
		db.SecondaryTotem = SPELL_TRANQUIL_AIR;
	else
		db.SecondaryTotem = SPELL_GRACE_OF_AIR;
	end
	COE_Twist:RefreshUI();
end

function COE_Twist:ToggleMenu()
	if( not COE_TwistFrame ) then
		return;
	end
	if( COE_TwistFrame:IsVisible() ) then
		COE_TwistFrame:Hide();
	else
		COE_Twist:RefreshUI();
		COE_TwistFrame:Show();
	end
	PlaySound( "igMainMenuOptionCheckBoxOn" );
end

function COE_Twist:UpdateLiveStatus()
	local db = GetTwistDB();
	local rem = COE_Twist:GetRemainingWF();
	local nextSpell, nextID = COE_Twist:GetNextSpell( false );

	if( COE_TwistActionButtonIcon and nextID ) then
		local tex = GetSpellTexture( nextID, BOOKTYPE_SPELL );
		if( tex ) then
			COE_TwistActionButtonIcon:SetTexture( tex );
		end
	end

	if( COE_TwistActionLabel ) then
		if( rem > 0 and COE_Twist.NeedSecondary ) then
			COE_TwistActionLabel:SetText( "Next: " .. (nextSpell or db.SecondaryTotem) );
		elseif( rem > 0 ) then
			COE_TwistActionLabel:SetText( string.format( "WF Active: %.1fs", rem ) );
		else
			COE_TwistActionLabel:SetText( "Next: Windfury Totem" );
		end
	end

	if( COE_TwistStatusBar ) then
		COE_TwistStatusBar:SetMinMaxValues( 0, db.RefreshTime );
		COE_TwistStatusBar:SetValue( rem );
		if( rem <= 1.5 and rem > 0 ) then
			COE_TwistStatusBar:SetStatusBarColor( 1.0, 0.5, 0.0 );
		elseif( rem > 0 ) then
			COE_TwistStatusBar:SetStatusBarColor( 0.2, 0.85, 0.4 );
		else
			COE_TwistStatusBar:SetStatusBarColor( 0.5, 0.5, 0.5 );
		end
	end
end

function COE_Twist:RefreshUI()
	local db = GetTwistDB();

	if( COE_TwistAutoCheck ) then
		COE_TwistAutoCheck:SetChecked( db.AutoTwist and 1 or 0 );
	end
	if( COE_TwistCombatCheck ) then
		COE_TwistCombatCheck:SetChecked( db.CombatOnly and 1 or 0 );
	end
	if( COE_TwistAlertCheck ) then
		COE_TwistAlertCheck:SetChecked( db.ManualAlert and 1 or 0 );
	end
	if( COE_TwistSecondaryButton ) then
		local shortName = (db.SecondaryTotem == SPELL_TRANQUIL_AIR) and "Tranquil Air" or "Grace of Air";
		COE_TwistSecondaryButton:SetText( "Secondary: " .. shortName );
	end
	if( COE_TwistRefreshSlider ) then
		COE_Twist.UpdatingSlider = true;
		COE_TwistRefreshSlider:SetValue( db.RefreshTime );
		COE_Twist.UpdatingSlider = false;
	end
	if( COE_TwistRefreshSliderText ) then
		COE_TwistRefreshSliderText:SetText( string.format( "WF Refresh: %.1fs", db.RefreshTime ) );
	end
	if( COEMinimapButtonGlow ) then
		if( db.AutoTwist ) then
			COEMinimapButtonGlow:Show();
		else
			COEMinimapButtonGlow:Hide();
		end
	end

	COE_Twist:UpdateLiveStatus();
end

-- ============================================================================
-- UI Event Handlers
-- ============================================================================

function COE_Twist:OnAutoCheckClick()
	local db = GetTwistDB();
	db.AutoTwist = (this:GetChecked() == 1);
	COE_Twist:RefreshUI();
end

function COE_Twist:OnCombatCheckClick()
	local db = GetTwistDB();
	db.CombatOnly = (this:GetChecked() == 1);
end

function COE_Twist:OnAlertCheckClick()
	local db = GetTwistDB();
	db.ManualAlert = (this:GetChecked() == 1);
end

function COE_Twist:OnRefreshSliderChange()
	if( COE_Twist.UpdatingSlider ) then
		return;
	end
	local db = GetTwistDB();
	local val = math.floor( this:GetValue() * 2 + 0.5 ) / 2;
	db.RefreshTime = val;
	if( COE_TwistRefreshSliderText ) then
		COE_TwistRefreshSliderText:SetText( string.format( "WF Refresh: %.1fs", val ) );
	end
end

-- ============================================================================
-- Minimap Button
-- ============================================================================

function COE_Twist:UpdateMinimapPosition()
	if( not COEMinimapButton or not Minimap ) then
		return;
	end
	local db = GetTwistDB();
	if( not db.ShowMinimap ) then
		COEMinimapButton:Hide();
		return;
	end
	local angle = db.MinimapAngle or 225;
	local rad = math.rad( angle );
	local x = math.cos( rad ) * 80;
	local y = math.sin( rad ) * 80;
	COEMinimapButton:ClearAllPoints();
	COEMinimapButton:SetPoint( "CENTER", Minimap, "CENTER", x, y );
	COEMinimapButton:Show();
end

function COE_Twist:OnMinimapDragUpdate()
	if( not this.isDragging or not Minimap ) then
		return;
	end
	local mx, my = Minimap:GetCenter();
	local cx, cy = GetCursorPosition();
	local scale = Minimap:GetEffectiveScale();
	cx = cx / scale;
	cy = cy / scale;
	local angle = math.deg( math.atan2( cy - my, cx - mx ) );
	if( angle < 0 ) then
		angle = angle + 360;
	end
	local db = GetTwistDB();
	db.MinimapAngle = angle;
	COE_Twist:UpdateMinimapPosition();
end

function COE_Twist:OnMinimapClick( button )
	if( IsShiftKeyDown() and button == "LeftButton" ) then
		COE_Twist:TwistNow();
	elseif( button == "RightButton" ) then
		COE:ToggleConfigFrame();
	else
		COE_Twist:ToggleMenu();
	end
end

function COE_Twist:OnMinimapEnter()
	local db = GetTwistDB();
	GameTooltip:SetOwner( this, "ANCHOR_LEFT" );
	GameTooltip:SetText( "Call Of Elements", 1.0, 0.82, 0.0 );
	GameTooltip:AddLine( "Auto Twist: " .. (db.AutoTwist and "|cff00ff00ON|r" or "|cffff4444OFF|r"), 1, 1, 1 );
	GameTooltip:AddLine( "Left-Click: Totem Twist Menu", 0.8, 0.8, 0.8 );
	GameTooltip:AddLine( "Right-Click: COE Configuration", 0.8, 0.8, 0.8 );
	GameTooltip:AddLine( "Shift+Left-Click: Twist Now", 0.8, 0.8, 0.8 );
	GameTooltip:AddLine( "Drag: Move Button", 0.6, 0.6, 0.6 );
	GameTooltip:Show();
end
