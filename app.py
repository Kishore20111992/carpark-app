import streamlit as st
import pandas as pd
from datetime import datetime
import time

from database import (
    init_db,
    get_slots,
    get_slot,
    get_slot_by_number,
    set_slot_status,
    get_rates,
    update_rate,
    get_active_tickets,
    get_all_tickets,
    find_active_ticket_by_vehicle,
    find_active_reservation_by_vehicle,
    get_ticket_by_id,
    reset_to_clean_production
)
from parking_manager import (
    suggest_best_slot,
    check_in_vehicle,
    calculate_parking_bill,
    check_out_vehicle,
    create_reservation,
    cancel_reservation,
    get_reservations,
    get_dashboard_metrics,
    EV_CHARGING_FLAT_FEE,
    TAX_RATE,
    CURRENCY_SYMBOL,
    process_fastag_payment,
    expire_no_show_reservations,
    check_in_from_reservation,
    validate_phone_number,
    start_realtime_background_worker,
    get_kpi_drilldown_data,
    detect_fastag_id
)

# Initialize database and seed data on first run
init_db()

# Start background real-time daemon worker for auto-sweeping expired bookings
start_realtime_background_worker(interval_seconds=5)

# --- STREAMLIT PAGE CONFIG ---
st.set_page_config(
    page_title="ParkFlow | Smart Parking Management",
    page_icon="🅿️",
    layout="wide",
    initial_sidebar_state="expanded"
)

def render_html(markup: str):
    """Renders raw HTML safely in Streamlit, stripping any indentation that triggers Markdown code-blocks."""
    clean = "\n".join(line.strip() for line in markup.strip().splitlines())
    st.markdown(clean, unsafe_allow_html=True)

# --- MODERN STYLING (CSS) ---
st.markdown("""
<style>
    /* Global polish */
    .block-container {
        padding-top: 1.5rem;
        padding-bottom: 2.5rem;
    }
    
    /* Top Brand Banner */
    .brand-header {
        background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
        color: white;
        padding: 1.2rem 1.8rem;
        border-radius: 12px;
        margin-bottom: 1.2rem;
        display: flex;
        align-items: center;
        justify-content: space-between;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
    .brand-title {
        font-size: 1.7rem;
        font-weight: 700;
        margin: 0;
        letter-spacing: -0.5px;
        display: flex;
        align-items: center;
        gap: 10px;
    }
    .brand-subtitle {
        color: #94a3b8;
        font-size: 0.95rem;
        margin-top: 4px;
    }

    /* KPI Metric Cards */
    .metric-container {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 12px;
        margin-bottom: 1.2rem;
    }
    .kpi-card {
        background: white;
        border: 2px solid #e2e8f0;
        border-radius: 12px;
        padding: 1.1rem 1.2rem;
        box-shadow: 0 2px 4px rgba(0,0,0,0.04);
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        cursor: pointer;
        position: relative;
        text-align: center;
        user-select: none;
    }
    .kpi-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 10px 20px rgba(59, 130, 246, 0.18);
        border-color: #3b82f6;
    }
    .kpi-card.active-kpi {
        border-color: #2563eb !important;
        background: linear-gradient(180deg, #eff6ff 0%, #ffffff 100%) !important;
        box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.25), 0 8px 20px rgba(37, 99, 235, 0.15) !important;
    }
    .kpi-label {
        font-size: 0.8rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: #64748b;
        font-weight: 600;
    }
    .kpi-value {
        font-size: 1.8rem;
        font-weight: 700;
        color: #0f172a;
        margin-top: 4px;
    }
    .kpi-sub {
        font-size: 0.8rem;
        color: #10b981;
        font-weight: 500;
        margin-top: 2px;
    }
    .kpi-click-hint {
        font-size: 0.72rem;
        margin-top: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 4px;
        font-weight: 600;
        color: #64748b;
        letter-spacing: 0.02em;
    }
    .kpi-card:hover .kpi-click-hint {
        color: #2563eb;
    }
    .kpi-card.active-kpi .kpi-click-hint {
        color: #1d4ed8;
        font-weight: 700;
    }

    /* KPI Drilldown Inspection Panel Styles */
    .drilldown-container {
        background: #ffffff;
        border: 2px solid #3b82f6;
        border-radius: 14px;
        padding: 22px 24px;
        box-shadow: 0 10px 25px rgba(37, 99, 235, 0.12);
        margin-bottom: 20px;
    }

    /* Parking Stall Grid Card */
    .bay-card {
        border-radius: 10px;
        padding: 12px;
        margin-bottom: 12px;
        border: 2px solid;
        text-align: center;
        background-color: #ffffff;
        box-shadow: 0 2px 6px rgba(0,0,0,0.05);
    }
    .bay-card.available {
        border-color: #10b981;
        background: linear-gradient(180deg, #ffffff 0%, #ecfdf5 100%);
    }
    .bay-card.occupied {
        border-color: #ef4444;
        background: linear-gradient(180deg, #ffffff 0%, #fef2f2 100%);
    }
    .bay-card.reserved {
        border-color: #f59e0b;
        background: linear-gradient(180deg, #ffffff 0%, #fffbeb 100%);
    }
    .bay-card.maintenance {
        border-color: #94a3b8;
        background: #f1f5f9;
    }

    .bay-badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 9999px;
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        margin-bottom: 4px;
    }
    .badge-available { background-color: #d1fae5; color: #065f46; }
    .badge-occupied { background-color: #fee2e2; color: #991b1b; }
    .badge-reserved { background-color: #fef3c7; color: #92400e; }
    .badge-maintenance { background-color: #e2e8f0; color: #475569; }

    /* Digital Parking Pass */
    .pass-ticket {
        background: #fff;
        border: 2px dashed #3b82f6;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 4px 15px rgba(59, 130, 246, 0.1);
        font-family: 'Courier New', Courier, monospace;
    }
    .pass-header {
        text-align: center;
        border-bottom: 1px dashed #93c5fd;
        padding-bottom: 10px;
        margin-bottom: 15px;
    }
    .pass-row {
        display: flex;
        justify-content: space-between;
        margin-bottom: 8px;
        font-size: 0.95rem;
    }
    .pass-row .pass-key { color: #64748b; }
    .pass-row .pass-val { font-weight: bold; color: #0f172a; }

    /* Receipt Box */
    .receipt-box {
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 10px;
        padding: 16px;
        margin-top: 10px;
    }

    @keyframes live-pulse {
        0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.7); }
        70% { transform: scale(1.1); box-shadow: 0 0 0 8px rgba(34, 197, 94, 0); }
        100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
    }
    .live-dot {
        display: inline-block;
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background-color: #22c55e;
        animation: live-pulse 1.8s infinite;
    }
</style>
""", unsafe_allow_html=True)

# Synchronize URL query parameter with session state
qp_kpi = st.query_params.get("kpi")
if qp_kpi in ["capacity", "available", "occupied", "occupancy", "revenue"]:
    st.session_state["selected_kpi"] = qp_kpi
elif "kpi" in st.query_params and not qp_kpi:
    st.session_state["selected_kpi"] = None

def render_kpi_drilldown_panel(active_kpi: str):
    data = get_kpi_drilldown_data(active_kpi)
    if not data:
        return

    st.markdown("---")
    
    # Inspection Header Banner with Title, live badge, and Close Button
    head_col1, head_col2 = st.columns([5, 1])
    with head_col1:
        if active_kpi == "capacity":
            icon_title = "🏢 Facility Total Capacity & Physical Stall Inventory"
            sub_desc = "Complete 24-bay layout across 3 vertical facility levels (Ground, Level 1, Level 2)"
        elif active_kpi == "available":
            icon_title = "🟢 Ready-To-Park Bays & Hourly Tariffs Directory"
            sub_desc = f"{data['available_count']} bays currently vacant, clean, and ready for immediate vehicle check-in"
        elif active_kpi == "occupied":
            icon_title = "🚗 Active Parked Vehicles & Real-Time Billing Telemetry"
            sub_desc = f"{data['occupied_count']} active parking sessions currently underway with live meter accumulation"
        elif active_kpi == "occupancy":
            icon_title = "📈 Facility Space Utilization & Congestion Analysis"
            sub_desc = f"Current utilization is {data['overall_occupancy_pct']}% with optimal vehicle turnaround flow"
        elif active_kpi == "revenue":
            icon_title = "💰 Today's Financial Revenue & Settlement Audit Statement"
            sub_desc = f"Audited total of {CURRENCY_SYMBOL}{data['total_today_revenue']:.2f} collected from completed tickets & forfeited reservation deposits"
        else:
            icon_title = "📊 KPI Detail Inspection"
            sub_desc = ""

        st.markdown(f"### {icon_title}")
        st.caption(f"{sub_desc} &bull; Refreshed at {datetime.now().strftime('%H:%M:%S')}")

    with head_col2:
        st.write("")
        if st.button("❌ Close Inspection", key="close_kpi_top", type="secondary", use_container_width=True):
            st.session_state["selected_kpi"] = None
            if "kpi" in st.query_params:
                del st.query_params["kpi"]
            st.rerun()

    # --- KPI 1: TOTAL CAPACITY ---
    if active_kpi == "capacity":
        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Total Facility Bays", f"{data['total_slots']} Slots", "100% Physical Inventory")
        m2.metric("Operational Floors", "3 Levels", "Zone A, B, C")
        m3.metric("Vehicle Categories", f"{len(data['type_summary'])} Supported", "Car, EV, SUV, Bike")
        m4.metric("Hourly Peak Capacity", f"{CURRENCY_SYMBOL}1,160 / hr", "At 100% facility occupancy")

        col_z, col_t = st.columns(2)
        with col_z:
            st.markdown("##### 🏢 Floor / Zone Distribution")
            zone_rows = []
            for z, count in data["zone_summary"].items():
                zone_rows.append({
                    "Floor / Zone": z,
                    "Total Stalls": count,
                    "Floor Capacity Share": f"{round(count/data['total_slots']*100, 1)}%"
                })
            st.dataframe(pd.DataFrame(zone_rows), use_container_width=True, hide_index=True)

        with col_t:
            st.markdown("##### 🚗 Vehicle Category Allocation & Base Rates")
            type_rows = []
            rates = get_rates()
            for t, count in data["type_summary"].items():
                rate_val = rates.get(t, {}).get("hourly_rate", 50.0)
                type_rows.append({
                    "Vehicle Type": t,
                    "Total Bays": count,
                    "Allocation Share": f"{round(count/data['total_slots']*100, 1)}%",
                    "Base Tariff": f"{CURRENCY_SYMBOL}{rate_val:.2f}/hr"
                })
            st.dataframe(pd.DataFrame(type_rows), use_container_width=True, hide_index=True)

        st.markdown("##### 📋 Complete 24-Bay Facility Inventory Directory")
        all_slots_df = pd.DataFrame([
            {
                "Bay Code": s["slot_number"],
                "Floor / Zone": s["zone"],
                "Designated Category": s["slot_type"],
                "Current Status": s["status"],
                "Base Tariff": f"{CURRENCY_SYMBOL}{rates.get(s['slot_type'], {}).get('hourly_rate', 50.0):.2f}/hr"
            }
            for s in data["slots"]
        ])
        st.dataframe(all_slots_df, use_container_width=True, hide_index=True)

    # --- KPI 2: AVAILABLE BAYS ---
    elif active_kpi == "available":
        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Available Right Now", f"{data['available_count']} Bays", f"{round(data['available_count']/24*100, 1)}% of facility")
        m2.metric("Available Car Bays", f"{data['type_counts'].get('Car', 0)} Stalls", "₹50.00/hr base")
        m3.metric("Available EV Chargers", f"{data['type_counts'].get('EV', 0)} Stalls", "₹60.00/hr + ₹150 EV")
        m4.metric("Available SUV Bays", f"{data['type_counts'].get('SUV', 0)} Stalls", "₹70.00/hr base")

        col_z, col_t = st.columns(2)
        with col_z:
            st.markdown("##### 🟢 Availability by Floor / Zone")
            z_rows = [{"Floor / Zone": z, "Available Bays": c} for z, c in data["zone_counts"].items()]
            st.dataframe(pd.DataFrame(z_rows), use_container_width=True, hide_index=True)

        with col_t:
            st.markdown("##### 🚗 Availability by Category")
            t_rows = [{"Category": t, "Available Bays": c} for t, c in data["type_counts"].items()]
            st.dataframe(pd.DataFrame(t_rows), use_container_width=True, hide_index=True)

        st.markdown("##### ⚡ Instant Ready-to-Park Bays Directory")
        avail_df = pd.DataFrame([
            {
                "Bay Code": s["slot_number"],
                "Floor / Zone": s["zone"],
                "Category": s["slot_type"],
                "Hourly Tariff": f"{CURRENCY_SYMBOL}{s['hourly_rate']:.2f}/hr",
                "Status": "🟢 Ready to Park"
            }
            for s in data["slots"]
        ])
        st.dataframe(avail_df, use_container_width=True, hide_index=True)
        st.info("💡 **Quick Tip**: To park a vehicle in any of these bays, proceed to the **'🚗 Vehicle Check-In'** tab below. The system will automatically suggest and allocate the nearest available bay.")

    # --- KPI 3: OCCUPIED BAYS ---
    elif active_kpi == "occupied":
        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Active Occupied Bays", f"{data['occupied_count']} Vehicles", f"{round(data['occupied_count']/24*100, 1)}% of facility")
        tot_accrued = sum(v["accrued_total"] for v in data["active_vehicles"])
        m2.metric("Total Metered Value", f"{CURRENCY_SYMBOL}{tot_accrued:.2f}", "Accruing in real time")
        ev_active = sum(1 for v in data["active_vehicles"] if v.get("is_ev_charging"))
        m3.metric("EV Charging Sessions", f"{ev_active} Active", "High-power AC/DC")
        avg_dwell = round(sum(v["duration_minutes"] for v in data["active_vehicles"]) / max(len(data["active_vehicles"]), 1), 1)
        m4.metric("Avg Active Dwell", f"{avg_dwell} mins", "Live telemetry")

        st.markdown("##### 🚗 Active Parked Vehicles Telemetry")
        if not data["active_vehicles"]:
            st.success("🎉 All bays are currently vacant! No active vehicles are parked.")
        else:
            for v in data["active_vehicles"]:
                with st.container():
                    render_html(f"""
                    <div style="background: #ffffff; border: 1px solid #fed7aa; border-left: 5px solid #f97316; border-radius: 10px; padding: 16px; margin-bottom: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                            <div>
                                <span style="font-size: 1.2rem; font-weight: 800; color: #0f172a; letter-spacing: 0.05em;">🚗 {v['vehicle_number']}</span>
                                <span style="background: #e2e8f0; color: #334155; padding: 3px 8px; border-radius: 6px; font-size: 0.8rem; font-weight: 600; margin-left: 8px;">{v['vehicle_type']}</span>
                                {'<span style="background: #dcfce7; color: #166534; padding: 3px 8px; border-radius: 6px; font-size: 0.8rem; font-weight: 700; margin-left: 6px;">⚡ EV CHARGING ACTIVE</span>' if v.get('is_ev_charging') else ''}
                            </div>
                            <div style="text-align: right;">
                                <span style="background: #fee2e2; color: #991b1b; padding: 4px 10px; border-radius: 20px; font-size: 0.8rem; font-weight: 700;">OCCUPIED &bull; BAY {v['slot_number']}</span>
                            </div>
                        </div>
                        <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; font-size: 0.88rem; color: #475569; margin-top: 10px;">
                            <div><b>Ticket ID:</b> <br><code style="color: #2563eb;">{v['ticket_id']}</code></div>
                            <div><b>Check-In Time:</b> <br>{v['entry_time']}</div>
                            <div><b>Parked Duration:</b> <br><b style="color: #0f172a;">{v['duration_formatted']}</b></div>
                            <div><b>Current Accrued Bill:</b> <br><b style="color: #16a34a; font-size: 1.05rem;">{CURRENCY_SYMBOL}{v['accrued_total']:.2f}</b> <span style="font-size: 0.75rem;">(incl. 18% GST)</span></div>
                        </div>
                    </div>
                    """)
                    
                    c_act1, c_act2 = st.columns([4, 1])
                    with c_act2:
                        if st.button(f"💳 Check-Out {v['slot_number']}", key=f"btn_co_v_{v['ticket_id']}", use_container_width=True, type="primary"):
                            st.session_state["checkout_ticket_search"] = v["ticket_id"]
                            st.toast(f"Ticket {v['ticket_id']} loaded! Open 'Check-Out & Billing' tab to settle payment.", icon="💳")

    # --- KPI 4: OCCUPANCY RATE ---
    elif active_kpi == "occupancy":
        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Facility Occupancy", f"{data['overall_occupancy_pct']}%", "Space utilization")
        all_slots_cnt = sum(z["total"] for z in data["zone_stats"].values())
        occ_slots_cnt = sum(z["occupied"] for z in data["zone_stats"].values())
        m2.metric("Occupied / Total Stalls", f"{occ_slots_cnt} / {all_slots_cnt} Bays", "Active vehicles")
        res_slots_cnt = sum(z["reserved"] for z in data["zone_stats"].values())
        m3.metric("Advance Reservations", f"{res_slots_cnt} Bays", "Prepaid 1-hr window")
        avail_cnt = sum(z["available"] for z in data["zone_stats"].values())
        m4.metric("Available Capacity", f"{avail_cnt} Bays", "Ready for parking")

        st.markdown("##### 🏢 Floor-by-Floor Space Utilization")
        z_cols = st.columns(len(data["zone_stats"]))
        for zcol, (zname, zstat) in zip(z_cols, data["zone_stats"].items()):
            with zcol:
                st.markdown(f"**{zname}**")
                pct = zstat["occupancy_pct"]
                st.progress(min(pct / 100.0, 1.0))
                st.write(f"Occupancy: **{pct}%** ({zstat['occupied']}/{zstat['total']} bays)")
                st.caption(f"Available: {zstat['available']} | Reserved: {zstat['reserved']}")

        st.markdown("##### 📊 Vehicle Category Utilization Matrix")
        type_matrix = []
        for tname, tstat in data["type_stats"].items():
            type_matrix.append({
                "Category": tname,
                "Total Bays": tstat["total"],
                "Occupied": tstat["occupied"],
                "Available": tstat["available"],
                "Reserved": tstat["reserved"],
                "Utilization Rate": f"{tstat['occupancy_pct']}%"
            })
        st.dataframe(pd.DataFrame(type_matrix), use_container_width=True, hide_index=True)

        if data["overall_occupancy_pct"] < 60:
            st.success("🟢 **Operational Flow: Optimal / Low Congestion** — Plenty of bays available across all floors.")
        elif data["overall_occupancy_pct"] < 85:
            st.warning("🟡 **Operational Flow: Moderate Load** — Consider guiding incoming vehicles to upper levels.")
        else:
            st.error("🔴 **Operational Flow: High Congestion / Near Capacity** — Restrict drive-up check-ins to reserved slots only.")

    # --- KPI 5: TODAY'S REVENUE ---
    elif active_kpi == "revenue":
        m1, m2, m3, m4 = st.columns(4)
        m1.metric("Today's Total Revenue", f"{CURRENCY_SYMBOL}{data['total_today_revenue']:.2f}", "Total settled & retained")
        m2.metric("Settled Parking Fees", f"{CURRENCY_SYMBOL}{data['ticket_revenue']:.2f}", f"{len(data['settled_tickets'])} completed sessions")
        m3.metric("Forfeited Booking Deposits", f"{CURRENCY_SYMBOL}{data['deposit_revenue']:.2f}", f"{len(data['forfeited_reservations'])} expired no-shows")
        m4.metric("GST (18%) Collected", f"{CURRENCY_SYMBOL}{data['gst_collected']:.2f}", "Audited tax component")

        st.markdown("##### 💳 Payment Collection Channel Split")
        pay_cols = st.columns(max(len(data["payment_methods"]), 1))
        for pcol, (pmethod, pamt) in zip(pay_cols, data["payment_methods"].items()):
            with pcol:
                render_html(f"""
                <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; text-align: center;">
                    <div style="font-size: 0.8rem; color: #64748b; font-weight: 600;">{pmethod}</div>
                    <div style="font-size: 1.3rem; color: #0f172a; font-weight: 700; margin-top: 4px;">{CURRENCY_SYMBOL}{pamt:.2f}</div>
                </div>
                """)

        st.markdown("##### 🧾 Audited Daily Financial Transaction Records")
        rev_tab1, rev_tab2 = st.tabs(["🧾 Completed & Settled Parking Tickets", "📅 Forfeited Advance Reservation Deposits"])
        with rev_tab1:
            if not data["settled_tickets"]:
                st.info("No parking tickets settled yet today.")
            else:
                settled_df = pd.DataFrame([
                    {
                        "Ticket ID": t["ticket_id"],
                        "Vehicle Plate": t["vehicle_number"],
                        "Category": t["vehicle_type"],
                        "Bay #": t["slot_number"],
                        "In-Time": t["entry_time"],
                        "Out-Time": t.get("exit_time", ""),
                        "Total Paid": f"{CURRENCY_SYMBOL}{float(t.get('total_fee') or 0.0):.2f}",
                        "GST (18%)": f"{CURRENCY_SYMBOL}{float(t.get('tax') or 0.0):.2f}",
                        "Payment Channel": t.get("payment_method", "FASTag")
                    }
                    for t in data["settled_tickets"]
                ])
                st.dataframe(settled_df, use_container_width=True, hide_index=True)

        with rev_tab2:
            if not data["forfeited_reservations"]:
                st.info("No reservation deposits forfeited today.")
            else:
                forfeited_df = pd.DataFrame([
                    {
                        "Reservation ID": r["reservation_id"],
                        "Vehicle Plate": r["vehicle_number"],
                        "Reserved Bay": r["slot_number"],
                        "Scheduled Arrival": r["reserved_for"],
                        "Auto-Forfeited At": r.get("forfeited_at") or r["created_at"],
                        "Non-Refundable Deposit": f"{CURRENCY_SYMBOL}{float(r.get('deposit_amount') or 0.0):.2f}",
                        "Audit Status": "Forfeited (No-Show Expired)"
                    }
                    for r in data["forfeited_reservations"]
                ])
                st.dataframe(forfeited_df, use_container_width=True, hide_index=True)

    # Bottom close button
    st.write("")
    if st.button("❌ Close Inspection View", key="close_kpi_bottom", use_container_width=True):
        st.session_state["selected_kpi"] = None
        if "kpi" in st.query_params:
            del st.query_params["kpi"]
        st.rerun()

    st.markdown("---")

# --- REAL-TIME HEADER & DASHBOARD METRICS ---
@st.fragment(run_every="2s")
def render_realtime_header_and_metrics():
    metrics = get_dashboard_metrics()
    now_str = datetime.now().strftime("%d %b %Y | %H:%M:%S")
    active_kpi = st.session_state.get("selected_kpi")

    render_html(f"""
    <div class="brand-header">
        <div>
            <h1 class="brand-title">🅿️ ParkFlow</h1>
            <div class="brand-subtitle">Smart Parking Bay Management & Real-Time Allocation System</div>
        </div>
        <div style="text-align: right;">
            <span style="background: rgba(255,255,255,0.18); padding: 6px 14px; border-radius: 20px; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 8px;">
                <span class="live-dot"></span>
                <span><b>REAL-TIME LIVE</b> &bull; {now_str}</span>
            </span>
        </div>
    </div>
    """)

    col_kpi1, col_kpi2, col_kpi3, col_kpi4, col_kpi5 = st.columns(5)
    with col_kpi1:
        is_act = (active_kpi == "capacity")
        act_cls = "active-kpi" if is_act else ""
        render_html(f"""
        <a href="?kpi=capacity" target="_self" style="text-decoration: none; color: inherit; display: block;">
            <div class="kpi-card {act_cls}">
                <div class="kpi-label">Total Capacity</div>
                <div class="kpi-value">{metrics['total_slots']}</div>
                <div class="kpi-sub">Across 3 Floors</div>
                <div class="kpi-click-hint">{'👉 <b>INSPECTING</b>' if is_act else '👆 Click to inspect'}</div>
            </div>
        </a>
        """)
        if st.button("✅ Active" if is_act else "🔍 View Details", key="btn_kpi_capacity", use_container_width=True, type="primary" if is_act else "secondary"):
            if is_act:
                st.session_state["selected_kpi"] = None
                if "kpi" in st.query_params:
                    del st.query_params["kpi"]
            else:
                st.session_state["selected_kpi"] = "capacity"
                st.query_params["kpi"] = "capacity"
            st.rerun(scope="app")

    with col_kpi2:
        is_act = (active_kpi == "available")
        act_cls = "active-kpi" if is_act else ""
        render_html(f"""
        <a href="?kpi=available" target="_self" style="text-decoration: none; color: inherit; display: block;">
            <div class="kpi-card {act_cls}">
                <div class="kpi-label">Available Bays</div>
                <div class="kpi-value" style="color: #10b981;">{metrics['available_count']}</div>
                <div class="kpi-sub" style="color: #10b981;">Ready for parking</div>
                <div class="kpi-click-hint">{'👉 <b>INSPECTING</b>' if is_act else '👆 Click to inspect'}</div>
            </div>
        </a>
        """)
        if st.button("✅ Active" if is_act else "🔍 View Details", key="btn_kpi_available", use_container_width=True, type="primary" if is_act else "secondary"):
            if is_act:
                st.session_state["selected_kpi"] = None
                if "kpi" in st.query_params:
                    del st.query_params["kpi"]
            else:
                st.session_state["selected_kpi"] = "available"
                st.query_params["kpi"] = "available"
            st.rerun(scope="app")

    with col_kpi3:
        is_act = (active_kpi == "occupied")
        act_cls = "active-kpi" if is_act else ""
        render_html(f"""
        <a href="?kpi=occupied" target="_self" style="text-decoration: none; color: inherit; display: block;">
            <div class="kpi-card {act_cls}">
                <div class="kpi-label">Occupied Bays</div>
                <div class="kpi-value" style="color: #ef4444;">{metrics['occupied_count']}</div>
                <div class="kpi-sub" style="color: #ef4444;">Active Vehicles</div>
                <div class="kpi-click-hint">{'👉 <b>INSPECTING</b>' if is_act else '👆 Click to inspect'}</div>
            </div>
        </a>
        """)
        if st.button("✅ Active" if is_act else "🔍 View Details", key="btn_kpi_occupied", use_container_width=True, type="primary" if is_act else "secondary"):
            if is_act:
                st.session_state["selected_kpi"] = None
                if "kpi" in st.query_params:
                    del st.query_params["kpi"]
            else:
                st.session_state["selected_kpi"] = "occupied"
                st.query_params["kpi"] = "occupied"
            st.rerun(scope="app")

    with col_kpi4:
        is_act = (active_kpi == "occupancy")
        act_cls = "active-kpi" if is_act else ""
        render_html(f"""
        <a href="?kpi=occupancy" target="_self" style="text-decoration: none; color: inherit; display: block;">
            <div class="kpi-card {act_cls}">
                <div class="kpi-label">Occupancy Rate</div>
                <div class="kpi-value" style="color: #3b82f6;">{metrics['occupancy_pct']}%</div>
                <div class="kpi-sub" style="color: #3b82f6;">Facility Utilization</div>
                <div class="kpi-click-hint">{'👉 <b>INSPECTING</b>' if is_act else '👆 Click to inspect'}</div>
            </div>
        </a>
        """)
        if st.button("✅ Active" if is_act else "🔍 View Details", key="btn_kpi_occupancy", use_container_width=True, type="primary" if is_act else "secondary"):
            if is_act:
                st.session_state["selected_kpi"] = None
                if "kpi" in st.query_params:
                    del st.query_params["kpi"]
            else:
                st.session_state["selected_kpi"] = "occupancy"
                st.query_params["kpi"] = "occupancy"
            st.rerun(scope="app")

    with col_kpi5:
        is_act = (active_kpi == "revenue")
        act_cls = "active-kpi" if is_act else ""
        render_html(f"""
        <a href="?kpi=revenue" target="_self" style="text-decoration: none; color: inherit; display: block;">
            <div class="kpi-card {act_cls}">
                <div class="kpi-label">Today's Revenue</div>
                <div class="kpi-value" style="color: #8b5cf6;">{CURRENCY_SYMBOL}{metrics['today_revenue']:.2f}</div>
                <div class="kpi-sub" style="color: #8b5cf6;">Collected Settled Fees</div>
                <div class="kpi-click-hint">{'👉 <b>INSPECTING</b>' if is_act else '👆 Click to inspect'}</div>
            </div>
        </a>
        """)
        if st.button("✅ Active" if is_act else "🔍 View Details", key="btn_kpi_revenue", use_container_width=True, type="primary" if is_act else "secondary"):
            if is_act:
                st.session_state["selected_kpi"] = None
                if "kpi" in st.query_params:
                    del st.query_params["kpi"]
            else:
                st.session_state["selected_kpi"] = "revenue"
                st.query_params["kpi"] = "revenue"
            st.rerun(scope="app")

render_realtime_header_and_metrics()

active_kpi = st.session_state.get("selected_kpi")
if active_kpi:
    render_kpi_drilldown_panel(active_kpi)

# --- REAL-TIME SIDEBAR MONITOR ---
with st.sidebar:
    st.markdown("### ⚡ Real-Time Engine")
    render_html("""
    <div style="background: #0f172a; border-radius: 8px; padding: 14px; color: #f8fafc; font-size: 0.85rem; border: 1px solid #334155; margin-bottom: 15px;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px;">
            <span style="font-weight: 700; font-size: 0.95rem;">System Engine</span>
            <span style="display: inline-flex; align-items: center; gap: 6px; color: #4ade80; font-weight: 700;">
                <span class="live-dot" style="width: 8px; height: 8px;"></span> ACTIVE
            </span>
        </div>
        <hr style="border: 0; border-top: 1px solid #334155; margin: 8px 0;">
        <div style="margin: 5px 0;">🔄 <b>Live Visualizer</b>: Every 2s</div>
        <div style="margin: 5px 0;">📊 <b>KPI Metrics</b>: Every 2s</div>
        <div style="margin: 5px 0;">📡 <b>Auto-Expiry Daemon</b>: Every 5s</div>
        <div style="margin: 5px 0;">💾 <b>SQLite Engine</b>: High-Concurrency WAL</div>
    </div>
    """)

    if st.button("⚡ Force Global Sync Now", type="secondary", use_container_width=True):
        expire_no_show_reservations()
        st.toast("Real-time database sync triggered!", icon="⚡")
        st.rerun()

    st.markdown("---")
    st.markdown("##### 📍 Facility Info")
    st.caption("Municipal Smart Parking Complex")
    st.caption("Floor G, Level 1, Level 2")
    st.caption("FASTag Enabled &bull; NPCI NETC Switch")

# --- MAIN TABS ---
tab_visualizer, tab_checkin, tab_checkout, tab_finder, tab_reservations, tab_analytics, tab_mobile = st.tabs([
    "🗺️ Parking Bay Visualizer",
    "🚗 Vehicle Check-In",
    "💳 Check-Out & Billing",
    "🔍 Locate Vehicle",
    "📅 Reservations",
    "📊 Analytics & Rates",
    "📱 Mobile App (Android & iOS)"
])

# ==============================================================================
# TAB 1: PARKING LOT VISUALIZER (INTERACTIVE MAP)
# ==============================================================================
with tab_visualizer:
    st.subheader("🗺️ Live Parking Facility Grid")
    
    # Filter Toolbar
    f_col1, f_col2, f_col3 = st.columns(3)
    with f_col1:
        zone_filter = st.selectbox(
            "Filter by Zone / Floor",
            ["All Zones", "Zone A (Ground)", "Zone B (Level 1)", "Zone C (Level 2)"],
            key="vis_zone_filter"
        )
    with f_col2:
        type_filter = st.selectbox(
            "Filter by Bay Type",
            ["All Types", "Car", "EV", "Bike", "SUV", "Handicap"],
            key="vis_type_filter"
        )
    with f_col3:
        status_filter = st.selectbox(
            "Filter by Status",
            ["All Statuses", "Available", "Occupied", "Reserved", "Maintenance"],
            key="vis_status_filter"
        )

    # Real-Time Bay Visualizer Fragment (Refreshes automatically every 2 seconds)
    @st.fragment(run_every="2s")
    def render_realtime_bay_grid(z_filter, t_filter, s_filter):
        target_zone = None if z_filter == "All Zones" else z_filter
        target_type = None if t_filter == "All Types" else t_filter
        target_status = None if s_filter == "All Statuses" else s_filter

        slots = get_slots(zone=target_zone, slot_type=target_type, status=target_status)

        if not slots:
            st.info("No parking bays match the selected filters.")
            return

        # Group by Zone
        zones_dict = {}
        for s in slots:
            zones_dict.setdefault(s["zone"], []).append(s)

        # Type icons
        icon_map = {
            "Car": "🚗",
            "EV": "⚡",
            "Bike": "🏍️",
            "SUV": "🚙",
            "Handicap": "♿"
        }

        # Layout bays in responsive columns
        for zone_name, zone_slots in zones_dict.items():
            st.markdown(f"#### 📍 {zone_name} `({len(zone_slots)} Bays)`")
            
            # Grid of 4 columns per row
            num_cols = 4
            cols = st.columns(num_cols)
            for idx, slot in enumerate(zone_slots):
                col = cols[idx % num_cols]
                with col:
                    status_class = slot["status"].lower()
                    type_icon = icon_map.get(slot["slot_type"], "🚗")
                    badge_class = f"badge-{status_class}"

                    # Vehicle details if occupied
                    if slot["status"] == "Occupied" and slot["vehicle_number"]:
                        try:
                            e_dt = datetime.strptime(slot["entry_time"], "%Y-%m-%d %H:%M:%S")
                            mins = max(0, int((datetime.now() - e_dt).total_seconds() / 60))
                            dur_str = f"{mins // 60}h {mins % 60}m"
                        except Exception:
                            dur_str = "Parked"

                        veh_info_html = (
                            f'<div style="font-weight: 700; color: #1e293b; font-size: 0.95rem; margin-top: 4px;">'
                            f'{slot["vehicle_number"]}</div>'
                            f'<div style="font-size: 0.75rem; color: #64748b;">⏱️ {dur_str}</div>'
                        )
                    elif slot["status"] == "Available":
                        veh_info_html = '<div style="font-size: 0.8rem; color: #059669; font-weight: 600; margin-top: 4px;">Ready to Park</div>'
                    elif slot["status"] == "Reserved":
                        veh_info_html = '<div style="font-size: 0.8rem; color: #d97706; font-weight: 600; margin-top: 4px;">Held for Guest</div>'
                    else:
                        veh_info_html = '<div style="font-size: 0.8rem; color: #64748b; margin-top: 4px;">Out of Service</div>'

                    card_html = (
                        f'<div class="bay-card {status_class}">'
                        f'<div style="display: flex; justify-content: space-between; align-items: center;">'
                        f'<span style="font-weight: 800; font-size: 1.1rem; color: #0f172a;">{slot["slot_number"]}</span>'
                        f'<span class="bay-badge {badge_class}">{slot["status"]}</span>'
                        f'</div>'
                        f'<div style="margin: 8px 0; font-size: 1.3rem;">'
                        f'{type_icon} <span style="font-size: 0.85rem; font-weight: 600; color: #475569;">{slot["slot_type"]}</span>'
                        f'</div>'
                        f'{veh_info_html}'
                        f'</div>'
                    )
                    render_html(card_html)

                    # Expandable quick action menu per slot
                    with st.expander(f"⚙️ Manage {slot['slot_number']}", expanded=False):
                        st.caption(f"Notes: {slot['notes'] or 'None'}")
                        if slot["status"] == "Occupied":
                            st.write(f"Customer: **{slot['driver_name'] or 'N/A'}**")
                            st.write(f"Ticket: `{slot['ticket_id']}`")
                        elif slot["status"] == "Available":
                            if st.button("🔧 Mark Maintenance", key=f"maint_{slot['id']}"):
                                set_slot_status(slot["id"], "Maintenance")
                                st.toast(f"Slot {slot['slot_number']} marked Maintenance")
                                st.rerun()
                        elif slot["status"] == "Maintenance":
                            if st.button("✅ Restore to Available", key=f"avail_{slot['id']}"):
                                set_slot_status(slot["id"], "Available")
                                st.toast(f"Slot {slot['slot_number']} is now Available")
                                st.rerun()

            st.write("")

    render_realtime_bay_grid(zone_filter, type_filter, status_filter)

# ==============================================================================
# TAB 2: VEHICLE CHECK-IN & SMART ALLOCATION
# ==============================================================================
with tab_checkin:
    st.subheader("🚗 Vehicle Check-In & Digital Pass Issuer")

    # Quick Lookup for Guests Arriving with Advance Bookings
    with st.expander("📅 Arriving with an Advance Booking? Click to Check-In & Link FASTag", expanded=False):
        c_res_find1, c_res_find2 = st.columns([3, 1])
        with c_res_find1:
            search_res_val = st.text_input("Enter Booking ID or Vehicle License Plate", placeholder="Enter Booking Reference or Vehicle Registration Plate", key="tab2_res_search").strip().upper()
        with c_res_find2:
            st.write("")
            btn_find_res = st.button("🔍 Locate Booking", key="btn_tab2_find_res", use_container_width=True)
        if search_res_val:
            all_act_res = get_reservations(status="Active")
            matched_res = [r for r in all_act_res if r["reservation_id"] == search_res_val or r["vehicle_number"] == search_res_val]
            if matched_res:
                m_res = matched_res[0]
                auto_detected_tag = detect_fastag_id(m_res["vehicle_number"])
                st.success(
                    f"✅ **Booking Verified**: `{m_res['reservation_id']}` &bull; Vehicle: **{m_res['vehicle_number']}** ({m_res['vehicle_type']})\n\n"
                    f"🅿️ Designated Bay: **{m_res['slot_number']}** &bull; Upfront Deposit Credited: **{CURRENCY_SYMBOL}{m_res['deposit_amount']:.2f}**\n\n"
                    f"📡 **Entry Boom Barrier Sensor**: Auto-detected FASTag RFID ` {auto_detected_tag} ` linked with NPCI Switch."
                )
                if st.button(f"🎟️ Check-In {m_res['vehicle_number']} & Issue Pass", type="primary", key="btn_tab2_checkin_res", use_container_width=True):
                    try:
                        res_ticket = check_in_from_reservation(m_res["reservation_id"], fastag_id=auto_detected_tag)
                        st.session_state["latest_ticket"] = res_ticket
                        st.toast(f"✅ Checked in {m_res['vehicle_number']}! FASTag linked & {CURRENCY_SYMBOL}{m_res['deposit_amount']:.2f} deposit credited.", icon="🎟️")
                        st.rerun()
                    except Exception as ex:
                        st.error(f"Check-In failed: {ex}")
            else:
                st.warning("No active reservation found with this ID or Plate.")

    in_col1, in_col2 = st.columns([1.2, 1])
    
    with in_col1:
        st.markdown("##### 📝 Entry Details")
        
        c_v1, c_v2 = st.columns(2)
        with c_v1:
            v_plate = st.text_input("Vehicle Registration / Plate Number *", placeholder="Enter Vehicle Registration Plate", key="checkin_plate").strip().upper()

        # Check for active advance booking or active parked ticket for this plate
        active_res = find_active_reservation_by_vehicle(v_plate) if v_plate else None
        active_parked_tkt = find_active_ticket_by_vehicle(v_plate) if v_plate else None

        if active_parked_tkt:
            st.error(
                f"⚠️ **Vehicle Already Parked**: Vehicle **'{v_plate}'** is currently checked in to Bay **{active_parked_tkt['slot_number']}** "
                f"(Ticket: `{active_parked_tkt['ticket_id']}`, Entry: {active_parked_tkt['entry_time']})."
            )
            col_pk1, col_pk2 = st.columns(2)
            with col_pk1:
                if st.button(f"💳 Check-Out Bay {active_parked_tkt['slot_number']} First", key="btn_tab2_co_existing", type="primary", use_container_width=True):
                    st.session_state["checkout_ticket_search"] = active_parked_tkt["ticket_id"]
                    st.toast(f"Ticket {active_parked_tkt['ticket_id']} loaded for check-out. Switch to 'Check-Out & Billing' tab.", icon="💳")
            with col_pk2:
                if st.button(f"🔄 Auto-Close Bay {active_parked_tkt['slot_number']} & Allow Re-entry", key="btn_tab2_autoclose_existing", use_container_width=True):
                    check_out_vehicle(active_parked_tkt["ticket_id"], payment_method="Operator Reset / Re-entry")
                    st.toast(f"Closed previous session in Bay {active_parked_tkt['slot_number']}.", icon="✅")
                    st.rerun()

        elif active_res:
            render_html(f"""
            <div style="background: #ecfdf5; border: 2px solid #10b981; border-radius: 10px; padding: 14px 18px; margin: 10px 0;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-weight: 800; font-size: 1.05rem; color: #065f46;">🎉 Active Advance Booking Detected!</span>
                    <span style="background: #10b981; color: white; padding: 3px 10px; border-radius: 20px; font-weight: 700; font-size: 0.75rem;">BOOKING VERIFIED</span>
                </div>
                <div style="margin-top: 8px; font-size: 0.92rem; color: #1e293b;">
                    Booking Reference: <b>{active_res['reservation_id']}</b> &bull; Customer: <b>{active_res['customer_name']}</b> ({active_res['customer_phone']})
                </div>
                <div style="font-size: 0.92rem; color: #1e293b; margin-top: 3px;">
                    🅿️ Dedicated Reserved Bay: <b style="color: #059669; font-size: 1.15rem;">{active_res['slot_number']}</b> ({active_res['slot_type']})
                </div>
                <div style="font-size: 0.92rem; color: #059669; margin-top: 3px; font-weight: 600;">
                    💰 Upfront 1-Hour Deposit Paid: <b>{CURRENCY_SYMBOL}{active_res['deposit_amount']:.2f}</b> (Will be credited to this session)
                </div>
            </div>
            """)

        with c_v2:
            default_type_idx = 0
            all_types = ["Car", "EV", "Bike", "SUV", "Handicap"]
            if active_res and active_res.get("vehicle_type") in all_types:
                default_type_idx = all_types.index(active_res["vehicle_type"])
            v_type = st.selectbox("Vehicle Category *", all_types, index=default_type_idx, key="checkin_vtype")

        c_d1, c_d2 = st.columns(2)
        with c_d1:
            default_name = active_res["customer_name"] if active_res else ""
            d_name = st.text_input("Customer Full Name *", value=default_name, placeholder="Enter customer full name", key="checkin_dname")
        with c_d2:
            default_phone = active_res["customer_phone"] if active_res else ""
            d_phone = st.text_input(
                "Customer Phone Number *",
                value=default_phone,
                placeholder="Enter 10-digit phone number",
                help="Requires min 10 digits. Alphabetic characters are rejected.",
                key="checkin_dphone"
            )

        # RFID FASTag Sensor Auto-Detection
        detected_sensor_tag = detect_fastag_id(v_plate) if v_plate else ""
        fastag_input = st.text_input(
            "📡 FASTag RFID EPC Tag (Auto-Detected at Boom Barrier)",
            value=detected_sensor_tag,
            placeholder="Auto-detected at barrier sensor or enter tag",
            key="checkin_fastag"
        ).strip().upper()
        if detected_sensor_tag:
            st.caption(f"📡 **RFID Gate Sensor Active**: Tag `{fastag_input or detected_sensor_tag}` linked with NPCI NETC Switch")

        ev_charging_choice = False
        if v_type == "EV":
            ev_charging_choice = st.checkbox(f"⚡ Plug-in for EV Fast Charging (+{CURRENCY_SYMBOL}{EV_CHARGING_FLAT_FEE:.2f} Surcharge)", value=True, key="checkin_ev_plug")

        st.markdown("##### 🅿️ Slot Assignment")
        chosen_slot_id = None
        can_checkin = True

        if active_res:
            st.success(
                f"🅿️ **Assigned to Reserved Bay {active_res['slot_number']}** ({active_res['slot_type']}) "
                f"under Booking `{active_res['reservation_id']}`. Upfront payment will adjust at checkout."
            )
            chosen_slot_id = active_res["slot_id"]
            can_checkin = not bool(active_parked_tkt)
        else:
            alloc_mode = st.radio(
                "Slot Selection Mode",
                ["Smart Recommendation (Nearest Available)", "Manual Bay Selection"],
                horizontal=True,
                key="checkin_alloc_mode"
            )

            if alloc_mode == "Manual Bay Selection":
                # Strictly show ONLY bays matching this vehicle category
                avail_slots = get_slots(status="Available", slot_type=v_type)
                if not avail_slots:
                    st.warning(f"⚠️ No available {v_type} bays in the facility! Empty slots of other categories cannot be used.")
                    can_checkin = False
                else:
                    slot_options = {f"{s['slot_number']} - {s['zone']} ({s['slot_type']})": s["id"] for s in avail_slots}
                    selected_label = st.selectbox(f"Select Available {v_type} Bay ({len(avail_slots)} available)", list(slot_options.keys()), key="checkin_manual_slot")
                    chosen_slot_id = slot_options[selected_label]
            else:
                recommended = suggest_best_slot(v_type, is_ev_charging=ev_charging_choice)
                if recommended:
                    st.success(f"✨ Recommended Optimal Bay: **{recommended['slot_number']}** in **{recommended['zone']}** ({recommended['slot_type']} Bay)")
                    chosen_slot_id = recommended["id"]
                else:
                    st.error(f"❌ No matching available bays for {v_type}.")
                    can_checkin = False

        if active_parked_tkt:
            can_checkin = False

        btn_submit_label = f"🎟️ Check-In from Advance Booking (Bay {active_res['slot_number']}) & Issue Pass" if active_res else "🎟️ Complete Check-In & Print Ticket"
        if st.button(btn_submit_label, type="primary", use_container_width=True, disabled=not can_checkin, key="btn_checkin_submit"):
            if not v_plate:
                st.error("Please enter a valid vehicle license plate number.")
            else:
                try:
                    clean_phone = ""
                    if d_phone.strip():
                        clean_phone = validate_phone_number(d_phone, required=False)

                    final_tag = fastag_input or detected_sensor_tag

                    if active_res:
                        new_ticket = check_in_from_reservation(
                            active_res["reservation_id"],
                            is_ev_charging=ev_charging_choice,
                            fastag_id=final_tag
                        )
                        st.session_state["latest_ticket"] = new_ticket
                        st.toast(f"✅ Vehicle {v_plate} checked in from Booking {active_res['reservation_id']}! Bay {new_ticket['slot_number']} occupied.", icon="🎟️")
                        st.rerun()
                    else:
                        new_ticket = check_in_vehicle(
                            vehicle_number=v_plate,
                            vehicle_type=v_type,
                            driver_name=d_name,
                            driver_phone=clean_phone,
                            slot_id=chosen_slot_id,
                            is_ev_charging=ev_charging_choice,
                            fastag_id=final_tag
                        )
                        st.session_state["latest_ticket"] = new_ticket
                        st.toast(f"✅ Vehicle {v_plate} checked into Bay {new_ticket['slot_number']}!", icon="🎟️")
                        st.rerun()
                except ValueError as err:
                    st.error(f"⚠️ Check-In Failed: {err}")

    with in_col2:
        st.markdown("##### 🎫 Digital Parking Pass")
        if "latest_ticket" in st.session_state and st.session_state["latest_ticket"]:
            t = st.session_state["latest_ticket"]
            render_html(f"""
            <div class="pass-ticket">
                <div class="pass-header">
                    <h3 style="margin:0; color:#1e3a8a;">🅿️ PARKFLOW PASS</h3>
                    <small>MUNICIPAL SMART PARKING FACILITY</small>
                </div>
                <div class="pass-row">
                    <span class="pass-key">TICKET NO:</span>
                    <span class="pass-val" style="color: #2563eb;">{t['ticket_id']}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">ASSIGNED BAY:</span>
                    <span class="pass-val" style="font-size: 1.3rem; color: #059669;">{t['slot_number']}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">VEHICLE PLATE:</span>
                    <span class="pass-val">{t['vehicle_number']}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">VEHICLE TYPE:</span>
                    <span class="pass-val">{t['vehicle_type']}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">ENTRY TIME:</span>
                    <span class="pass-val">{t['entry_time']}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">HOURLY RATE:</span>
                    <span class="pass-val">{CURRENCY_SYMBOL}{t['rate_per_hour']:.2f} / hr</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">EV CHARGING:</span>
                    <span class="pass-val">{f'Yes ({CURRENCY_SYMBOL}{EV_CHARGING_FLAT_FEE:.2f} flat)' if t.get('is_ev_charging') else 'No'}</span>
                </div>
                <hr style="border: none; border-top: 1px dashed #cbd5e1; margin: 12px 0;">
                <div style="text-align: center; color: #475569; font-size: 0.8rem;">
                    <div>||| | |||| | |||||| || ||||| |||| |</div>
                    <div style="letter-spacing: 3px; font-weight: bold;">{t['ticket_id']}</div>
                    <div style="margin-top: 6px;">Keep this pass visible or present at checkout counter</div>
                </div>
            </div>
            """)
            
            c_clr1, c_clr2 = st.columns(2)
            with c_clr1:
                st.download_button(
                    "💾 Download Pass (TXT)",
                    data=f"PARKFLOW PASS\nTicket: {t['ticket_id']}\nBay: {t['slot_number']}\nVehicle: {t['vehicle_number']}\nEntry: {t['entry_time']}\nRate: {CURRENCY_SYMBOL}{t['rate_per_hour']}/hr",
                    file_name=f"Pass_{t['ticket_id']}.txt",
                    use_container_width=True
                )
            with c_clr2:
                if st.button("Clear Pass", use_container_width=True):
                    st.session_state["latest_ticket"] = None
                    st.rerun()
        else:
            st.info("Complete the form on the left to issue an active parking pass.")

# ==============================================================================
# TAB 3: VEHICLE CHECK-OUT & BILLING
# ==============================================================================
with tab_checkout:
    st.subheader("💳 Vehicle Check-Out & Cashier Billing Counter")
    
    active_tickets = get_active_tickets()
    
    if not active_tickets:
        st.success("🎉 All bays are currently empty! No vehicles waiting for check-out.")
    else:
        out_col1, out_col2 = st.columns([1.1, 1.2])
        
        with out_col1:
            st.markdown("##### 🔎 Select Active Vehicle")
            ticket_options = {
                f"{t['vehicle_number']} — Bay {t['slot_number']} ({t['vehicle_type']}, In: {t['entry_time'].split(' ')[1]})": t['ticket_id']
                for t in active_tickets
            }
            selected_ticket_label = st.selectbox("Search / Choose Parked Vehicle", list(ticket_options.keys()))
            selected_ticket_id = ticket_options[selected_ticket_label]
            
            selected_ticket = get_ticket_by_id(selected_ticket_id)

            st.markdown("##### ⏱️ Tariff Calculation Basis")
            tariff_basis = st.radio(
                "Calculation Basis",
                [
                    "Model B: 30-Minute Slabs (Prorated) [Standard]",
                    "Model A: Full Hourly Block (Ceiling)",
                    "Model C: Exact Per-Minute (Prorated)"
                ],
                index=0,
                horizontal=True
            )
            model_key = {
                "Model B: 30-Minute Slabs (Prorated) [Standard]": "prorated_30min",
                "Model A: Full Hourly Block (Ceiling)": "hourly_block",
                "Model C: Exact Per-Minute (Prorated)": "exact_prorata"
            }[tariff_basis]

            bill_preview = calculate_parking_bill(selected_ticket, billing_model=model_key)

            st.markdown("##### 💵 Payment Method")
            pay_method = st.radio(
                "Select Payment Mode",
                ["FASTag (NETC Auto-Debit)", "UPI / QR Scan", "Credit Card", "Cash"],
                horizontal=True
            )

            pay_amount = bill_preview["net_payable"]
            prepaid_dep = bill_preview["prepaid_deposit"]

            if pay_method == "FASTag (NETC Auto-Debit)":
                tag_display = selected_ticket.get('fastag_id') or detect_fastag_id(selected_ticket['vehicle_number'])
                st.info(f"📡 **FASTag Active**: Windshield Tag `{tag_display}` ready for auto-debit via NPCI NETC Switch.")

                if prepaid_dep > 0:
                    if pay_amount == 0.0:
                        st.success(
                            f"🟢 **Within 1-Hour Prepaid Window**: 100% of the parking fee ({CURRENCY_SYMBOL}{bill_preview['total_fee']:.2f}) "
                            f"is adjusted with your advance booking deposit. **NO DEBIT WILL OCCUR FROM FASTAG ({CURRENCY_SYMBOL}0.00).** "
                            f"Barrier opens automatically."
                        )
                        fastag_btn_label = f"⚡ Open Barrier (FASTag {CURRENCY_SYMBOL}0.00 Debit - Covered by Upfront Payment)"
                    else:
                        st.warning(
                            f"⏱️ **Duration Exceeded 1-Hour Prepaid Window (+{bill_preview['extra_mins']} mins)**: "
                            f"Upfront deposit of {CURRENCY_SYMBOL}{prepaid_dep:.2f} has been adjusted. "
                            f"**The extra duration fee of {CURRENCY_SYMBOL}{pay_amount:.2f} will be debited from linked FASTag ({tag_display}).**"
                        )
                        fastag_btn_label = f"⚡ Auto-Debit Extra Duration ({CURRENCY_SYMBOL}{pay_amount:.2f}) from FASTag"
                else:
                    fastag_btn_label = f"⚡ Instant FASTag Auto-Debit ({CURRENCY_SYMBOL}{pay_amount:.2f})"

                if st.button(fastag_btn_label, type="primary", use_container_width=True):
                    try:
                        receipt = process_fastag_payment(selected_ticket_id, tag_id=tag_display, billing_model=model_key)
                        st.session_state["latest_receipt"] = receipt
                        if pay_amount == 0.0:
                            st.toast("✅ Exit Cleared! Zero FASTag debit (100% covered by upfront booking deposit).", icon="🟢")
                        else:
                            st.toast(f"✅ Extra amount of {CURRENCY_SYMBOL}{pay_amount:.2f} debited from FASTag! Txn: {receipt['fastag_meta']['netc_txn_id']}", icon="📡")
                        st.rerun()
                    except Exception as e:
                        st.error(f"FASTag Error: {e}")
            else:
                settle_btn_label = f"🏁 Settle {CURRENCY_SYMBOL}{pay_amount:.2f} & Check-Out" if pay_amount > 0 else "🏁 Complete Exit (Prepaid via Booking)"
                if st.button(settle_btn_label, type="primary", use_container_width=True):
                    try:
                        receipt = check_out_vehicle(selected_ticket_id, payment_method=pay_method, billing_model=model_key)
                        st.session_state["latest_receipt"] = receipt
                        st.toast(f"✅ Vehicle {selected_ticket['vehicle_number']} checked out! Bay {selected_ticket['slot_number']} is now Available.", icon="💳")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Error during check-out: {e}")

        with out_col2:
            st.markdown("##### 🧾 Live Invoice & Payment Breakdown")

            if model_key == "prorated_30min":
                calc_name = "Model B (1st Hr Base + 30m Slabs)"
                if bill_preview["extra_slabs"] > 0:
                    extra_markup = f"""<div class="pass-row">
                        <span class="pass-key">Additional Time ({bill_preview['extra_mins']} mins):</span>
                        <span class="pass-val" style="color: #d97706;">+{CURRENCY_SYMBOL}{bill_preview['extra_charge']:.2f} ({bill_preview['extra_slabs']} slab(s) × {CURRENCY_SYMBOL}{bill_preview['slab_rate']:.2f})</span>
                    </div>"""
                else:
                    extra_markup = f"""<div class="pass-row">
                        <span class="pass-key">Additional Time:</span>
                        <span class="pass-val" style="color: #059669;">Within 1st hour (+{CURRENCY_SYMBOL}0.00)</span>
                    </div>"""
            elif model_key == "exact_prorata":
                calc_name = "Model C (Per-Minute Pro-Rata)"
                if bill_preview["extra_mins"] > 0:
                    extra_markup = f"""<div class="pass-row">
                        <span class="pass-key">Additional Time ({bill_preview['extra_mins']} mins):</span>
                        <span class="pass-val" style="color: #d97706;">+{CURRENCY_SYMBOL}{bill_preview['extra_charge']:.2f} ({bill_preview['extra_mins']}m @ {CURRENCY_SYMBOL}{bill_preview['rate_per_hour']/60:.2f}/min)</span>
                    </div>"""
                else:
                    extra_markup = f"""<div class="pass-row">
                        <span class="pass-key">Additional Time:</span>
                        <span class="pass-val" style="color: #059669;">Within 1st hour (+{CURRENCY_SYMBOL}0.00)</span>
                    </div>"""
            else:
                calc_name = "Model A (Full Hourly Block Ceiling)"
                extra_markup = f"""<div class="pass-row">
                    <span class="pass-key">Billed Hourly Units:</span>
                    <span class="pass-val">{bill_preview['billable_hours']} hr(s) @ {CURRENCY_SYMBOL}{bill_preview['rate_per_hour']:.2f}/hr</span>
                </div>"""

            prepaid_markup = ""
            if bill_preview["prepaid_deposit"] > 0:
                prepaid_markup = f"""
                <div class="pass-row" style="color: #059669; font-weight: 600;">
                    <span class="pass-key" style="color: #059669;">Advance Deposit Credited ({bill_preview.get('reservation_id', 'Res')}):</span>
                    <span class="pass-val" style="color: #059669;">-{CURRENCY_SYMBOL}{bill_preview['prepaid_deposit']:.2f}</span>
                </div>
                """

            render_html(f"""
            <div class="receipt-box">
                <div style="display: flex; justify-content: space-between; align-items: baseline; border-bottom: 2px solid #0f172a; padding-bottom: 8px;">
                    <div>
                        <h4 style="margin: 0; color: #0f172a;">Parking Fee Statement</h4>
                        <small style="color: #64748b;">Ticket: <b>{selected_ticket['ticket_id']}</b></small>
                    </div>
                    <span style="background: #e0e7ff; color: #3730a3; padding: 4px 10px; border-radius: 6px; font-weight: bold; font-size: 0.85rem;">
                        Bay {selected_ticket['slot_number']}
                    </span>
                </div>
                <div style="margin: 12px 0;">
                    <div class="pass-row">
                        <span class="pass-key">Vehicle Plate:</span>
                        <span class="pass-val">{selected_ticket['vehicle_number']} ({selected_ticket['vehicle_type']})</span>
                    </div>
                    <div class="pass-row">
                        <span class="pass-key">Customer Name:</span>
                        <span class="pass-val">{selected_ticket['driver_name'] or 'Walk-in Guest'}</span>
                    </div>
                    <div class="pass-row">
                        <span class="pass-key">Entry Timestamp:</span>
                        <span class="pass-val">{bill_preview['entry_time']}</span>
                    </div>
                    <div class="pass-row">
                        <span class="pass-key">Exit Timestamp:</span>
                        <span class="pass-val">{bill_preview['exit_time']}</span>
                    </div>
                    <div class="pass-row">
                        <span class="pass-key">Total Duration:</span>
                        <span class="pass-val" style="color: #2563eb;">{bill_preview['duration_formatted']} ({bill_preview['duration_minutes']} mins)</span>
                    </div>
                    <div class="pass-row">
                        <span class="pass-key">Tariff Policy:</span>
                        <span class="pass-val" style="color: #4338ca; font-weight: 600;">{calc_name}</span>
                    </div>
                    <div class="pass-row">
                        <span class="pass-key">1st Hour Base Fee:</span>
                        <span class="pass-val">{CURRENCY_SYMBOL}{bill_preview['base_first_hour_fee']:.2f}</span>
                    </div>
                    {extra_markup}
                </div>
                <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 10px 0;">
                <div class="pass-row">
                    <span class="pass-key">Parking Subtotal:</span>
                    <span class="pass-val">{CURRENCY_SYMBOL}{bill_preview['subtotal']:.2f}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">EV Charging Add-on:</span>
                    <span class="pass-val">{CURRENCY_SYMBOL}{bill_preview['ev_charging_fee']:.2f}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">GST (18%):</span>
                    <span class="pass-val">{CURRENCY_SYMBOL}{bill_preview['tax']:.2f}</span>
                </div>
                <div class="pass-row">
                    <span class="pass-key">Gross Total:</span>
                    <span class="pass-val">{CURRENCY_SYMBOL}{bill_preview['total_fee']:.2f}</span>
                </div>
                {prepaid_markup}
                <div style="display: flex; justify-content: space-between; margin-top: 10px; padding-top: 8px; border-top: 2px solid #0f172a; font-size: 1.25rem; font-weight: 800; color: #0f172a;">
                    <span>Net Balance Payable:</span>
                    <span style="color: {'#059669' if bill_preview['net_payable'] > 0 else '#2563eb'};">
                        {CURRENCY_SYMBOL}{bill_preview['net_payable']:.2f}
                    </span>
                </div>
            </div>
            """)

        if "latest_receipt" in st.session_state and st.session_state["latest_receipt"]:
            st.write("---")
            st.success("✅ **Last Transaction Completed!** Receipt generated below.")
            rc = st.session_state["latest_receipt"]
            rc_data = {
                "Receipt ID": rc["ticket_id"],
                "Vehicle": rc["vehicle_number"],
                "Total Paid": f"{CURRENCY_SYMBOL}{rc['total_fee']:.2f}",
                "Payment Method": rc["payment_method"],
                "Duration": f"{rc['duration_minutes']} minutes",
                "Exit Time": rc["exit_time"],
                "Status": "PAID"
            }
            if rc.get("fastag_meta"):
                rc_data["FASTag NETC Txn ID"] = rc["fastag_meta"]["netc_txn_id"]
                rc_data["RFID Tag ID"] = rc["fastag_meta"]["tag_id"]
                rc_data["FASTag Amount Debited"] = rc["fastag_meta"]["debited_amount"]
                rc_data["Upfront Deposit Adjusted"] = rc["fastag_meta"]["upfront_deposit_adjusted"]
                rc_data["NETC Status"] = rc["fastag_meta"]["debit_status"]
                rc_data["Audit Notes"] = rc["fastag_meta"]["notes"]
            st.json(rc_data)
            if st.button("Dismiss Receipt"):
                st.session_state["latest_receipt"] = None
                st.rerun()

# ==============================================================================
# TAB 4: LOCATE VEHICLE (FINDER)
# ==============================================================================
with tab_finder:
    st.subheader("🔍 Vehicle & Parking Bay Locator")
    st.caption("Help visitors quickly locate their vehicle's exact bay and floor level.")
    
    search_query = st.text_input("Enter License Plate or Ticket Number", placeholder="Enter Vehicle Registration Plate or Ticket ID").strip().upper()
    
    if search_query:
        found_ticket = find_active_ticket_by_vehicle(search_query)
        if not found_ticket:
            found_ticket = get_ticket_by_id(search_query)
        
        if found_ticket and found_ticket["is_active"]:
            slot = get_slot(found_ticket["slot_id"])
            bill = calculate_parking_bill(found_ticket)
            
            st.success(f"📍 **Vehicle Located!** Parked in **Bay {slot['slot_number']}**.")
            
            f1, f2, f3, f4 = st.columns(4)
            with f1:
                st.metric("Assigned Bay", slot["slot_number"], help="Exact parking spot")
            with f2:
                st.metric("Facility Zone", slot["zone"], help="Zone location")
            with f3:
                st.metric("Parked Duration", bill["duration_formatted"])
            with f4:
                st.metric("Current Accrued Fee", f"{CURRENCY_SYMBOL}{bill['total_fee']:.2f}")

            st.info(f"🧭 **Walking Directions**: Proceed to **{slot['zone']}** (Floor {slot['floor']}). {slot['notes'] or ''}")
        else:
            st.warning(f"No active parked vehicle found for '{search_query}'. Please verify the plate number or check if it was already checked out.")

# ==============================================================================
# TAB 5: ADVANCE RESERVATIONS
# ==============================================================================
with tab_reservations:
    st.subheader("📅 Reserve a Parking Bay in Advance")
    st.caption("Guaranteed parking spot allocation with 1-hour upfront base tariff deposit & automated no-show forfeiture.")

    # Auto-sweep for expired no-shows on page load
    swept_noshows = expire_no_show_reservations()
    if swept_noshows:
        for sn in swept_noshows:
            st.warning(
                f"⚠️ **Auto-Forfeiture Notice**: Reservation **{sn['reservation_id']}** ({sn['vehicle_number']} for Bay {sn['slot_number']}) "
                f"exceeded its 1-hour prepaid arrival window without checking in. Bay is now **Available**. "
                f"Non-refundable deposit of **{CURRENCY_SYMBOL}{sn['deposit_amount']:.2f}** retained in facility revenue."
            )
    
    res_col1, res_col2 = st.columns([1.1, 1.2])
    
    with res_col1:
        st.markdown("##### 📝 Create Advance Booking")
        
        # Vehicle Category selection placed reactively to filter dedicated bays
        r_type = st.selectbox(
            "Vehicle Category *",
            ["Car", "EV", "Bike", "SUV", "Handicap"],
            key="res_vtype_active",
            help="Select vehicle type to view dedicated matching bays. Empty bays of other categories are excluded."
        )

        # Strictly query bays matching ONLY the selected vehicle category
        avail_bays = get_slots(status="Available", slot_type=r_type)

        r_rates = get_rates()
        r_base = r_rates.get(r_type, {"hourly_rate": 50.0})["hourly_rate"]
        r_deposit_total = round(r_base * (1.0 + TAX_RATE), 2)

        if not avail_bays:
            st.error(
                f"🚫 **No Available {r_type} Bays**: All bays designated for '{r_type}' are currently occupied or reserved. "
                f"Under facility policy, empty bays of other categories cannot be allocated for a {r_type}."
            )
        else:
            with st.form("reserve_form", clear_on_submit=False):
                r_name = st.text_input("Customer Full Name *", placeholder="Enter customer full name", key="res_name")
                r_phone = st.text_input(
                    "Contact Phone Number * (10 Digits)",
                    placeholder="Enter 10-digit mobile number",
                    help="Must contain at least 10 digits. Alphabetic characters are strictly rejected.",
                    key="res_phone"
                )
                r_plate = st.text_input(f"{r_type} License Plate Number *", placeholder="Enter registration plate number", key="res_plate").strip().upper()

                r_d1, r_d2 = st.columns(2)
                with r_d1:
                    r_date = st.date_input("Scheduled Arrival Date", value=datetime.now())
                with r_d2:
                    r_time = st.time_input("Scheduled Arrival Time", value=datetime.now().time())

                # Show ONLY matching category bays in dropdown
                res_slot_options = {f"{s['slot_number']} - {s['zone']} ({s['slot_type']})": s["id"] for s in avail_bays}
                chosen_res_slot = st.selectbox(
                    f"Select Dedicated {r_type} Bay * ({len(avail_bays)} available)",
                    list(res_slot_options.keys())
                )
                chosen_res_id = res_slot_options[chosen_res_slot]

                r_pay_mode = st.selectbox(
                    "Upfront Deposit Payment Method * (Instant Online Settlement)",
                    ["UPI / QR Scan", "Credit / Debit Card", "Net Banking"],
                    help="Advance bookings require instant online payment to guarantee the bay. Cash/Counter payment and FASTag are disabled prior to physical arrival."
                )
                st.caption("ℹ️ *Cash / Counter Deposit and FASTag are disabled for advance bookings. Upfront deposits must be paid via instant online channels (UPI, Card, Net Banking). FASTag is scanned at check-in.*")

                render_html(f"""
                <div style="background: #fef2f2; border: 1px solid #fca5a5; border-radius: 8px; padding: 10px; margin: 10px 0; font-size: 0.85rem; color: #991b1b;">
                    <b>💰 1-Hour Prepaid Reservation Policy</b>: An upfront 1-hour base tariff deposit of 
                    <b>{CURRENCY_SYMBOL}{r_deposit_total:.2f}</b> (Base: {CURRENCY_SYMBOL}{r_base:.2f} + 18% GST) is collected to reserve this <b>{r_type}</b> bay. 
                    The bay is held exclusively for <b>1 hour</b> from the scheduled arrival time ({r_time.strftime('%H:%M')}). 
                    If the vehicle fails to check in during this 1-hour prepaid window, the booking automatically expires, 
                    the bay is restored to Available, and the 1st hour deposit is <b>strictly non-refundable</b>.
                </div>
                """)

                submit_res = st.form_submit_button(f"🔒 Pay {CURRENCY_SYMBOL}{r_deposit_total:.2f} & Confirm Booking", type="primary", use_container_width=True)
                if submit_res:
                    if not r_name.strip() or not r_phone.strip() or not r_plate.strip():
                        st.error("⚠️ Please fill in all required fields (Name, Phone Number, Vehicle Plate).")
                    elif not chosen_res_id:
                        st.error("⚠️ Please select an available bay.")
                    else:
                        try:
                            clean_res_phone = validate_phone_number(r_phone, required=True)
                            res_arrival_str = f"{r_date.strftime('%Y-%m-%d')} {r_time.strftime('%H:%M:%S')}"
                            new_res_id = create_reservation(
                                customer_name=r_name.strip(),
                                customer_phone=clean_res_phone,
                                vehicle_number=r_plate.strip().upper(),
                                vehicle_type=r_type,
                                slot_id=chosen_res_id,
                                reserved_for_str=res_arrival_str,
                                payment_method=r_pay_mode,
                                grace_period_mins=60,
                                deposit_amount=r_deposit_total
                            )
                            st.toast(f"✅ Slot Reserved! Reservation: {new_res_id} (Paid: {CURRENCY_SYMBOL}{r_deposit_total:.2f})", icon="📅")
                            st.rerun()
                        except ValueError as ve:
                            st.error(f"⚠️ Validation / Booking Error: {ve}")

    with res_col2:
        st.markdown("##### 📋 Reservation Records & Status")
        
        c_filter, c_sweep = st.columns([1.5, 1])
        with c_filter:
            res_filter = st.radio("Filter", ["Active Bookings", "No-Show Forfeited", "All Records"], horizontal=True)
        with c_sweep:
            st.write("")
            if st.button("⚡ Sweep Expired Now", help="Checks and forfeits reservations that exceeded their 1-hour prepaid arrival window."):
                manual_swept = expire_no_show_reservations()
                if manual_swept:
                    st.toast(f"Swept & forfeited {len(manual_swept)} expired booking(s)!", icon="🧹")
                else:
                    st.toast("All active bookings are within their 1-hour prepaid window.", icon="✅")
                st.rerun()

        @st.fragment(run_every="3s")
        def render_realtime_reservations(r_filter):
            if r_filter == "Active Bookings":
                disp_reservations = get_reservations(status="Active")
            elif r_filter == "No-Show Forfeited":
                disp_reservations = get_reservations(status="NoShow_Forfeited")
            else:
                disp_reservations = get_reservations()

            if not disp_reservations:
                st.info(f"No records found under '{r_filter}'.")
                return

            for r in disp_reservations:
                with st.container():
                    r_status = r["status"]
                    if r_status == "Active":
                        border_col = "#f59e0b"
                        bg_col = "#fffbeb"
                        badge_bg = "#fef3c7"
                        badge_txt = "#92400e"
                        status_label = "ACTIVE RESERVATION"
                    elif r_status == "NoShow_Forfeited":
                        border_col = "#ef4444"
                        bg_col = "#fef2f2"
                        badge_bg = "#fee2e2"
                        badge_txt = "#991b1b"
                        status_label = "NO-SHOW (DEPOSIT FORFEITED)"
                    elif r_status == "CheckedIn":
                        border_col = "#10b981"
                        bg_col = "#f0fdf4"
                        badge_bg = "#dcfce7"
                        badge_txt = "#166534"
                        status_label = "CHECKED-IN (DEPOSIT CREDITED)"
                    else:
                        border_col = "#94a3b8"
                        bg_col = "#f8fafc"
                        badge_bg = "#f1f5f9"
                        badge_txt = "#475569"
                        status_label = r_status.upper()

                    render_html(f"""
                    <div style="border: 1px solid {border_col}; background: {bg_col}; border-radius: 8px; padding: 12px; margin-bottom: 10px;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <span style="font-weight: 800; color: #0f172a; font-size: 1rem;">{r['reservation_id']}</span>
                            <span style="background: {badge_bg}; color: {badge_txt}; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 0.75rem;">
                                {status_label}
                            </span>
                        </div>
                        <div style="margin-top: 6px; font-size: 0.95rem; color: #1e293b;">
                            👤 <b>{r['customer_name']}</b> ({r['customer_phone']})
                        </div>
                        <div style="font-size: 0.85rem; color: #475569; margin-top: 2px;">
                            🚗 <b>{r['vehicle_number']}</b> ({r['vehicle_type']}) &bull; Bay <b>{r['slot_number']}</b>
                        </div>
                        <div style="font-size: 0.85rem; color: #475569; margin-top: 2px;">
                            ⏰ Scheduled: <b>{r['reserved_for']}</b> (1-Hour Prepaid Window)
                        </div>
                        <div style="margin-top: 6px; font-size: 0.85rem; font-weight: 600; color: #059669;">
                            💰 Upfront Deposit: {CURRENCY_SYMBOL}{r.get('deposit_amount', 0.0):.2f} (Paid via {r.get('payment_method', 'UPI')})
                        </div>
                        <div style="margin-top: 5px; font-size: 0.83rem; color: #2563eb; font-weight: 600;">
                            📡 Auto-Detected FASTag RFID: <code>{detect_fastag_id(r['vehicle_number'])}</code> (Ready for Barrier Auto-Link)
                        </div>
                    </div>
                    """)
                    
                    if r_status == "Active":
                        c_btn1, c_btn2 = st.columns(2)
                        with c_btn1:
                            if st.button("✅ Check-In (Credit Deposit)", key=f"res_in_{r['reservation_id']}", use_container_width=True):
                                try:
                                    tag_to_link = detect_fastag_id(r["vehicle_number"])
                                    new_t = check_in_from_reservation(r["reservation_id"], fastag_id=tag_to_link)
                                    st.session_state["latest_ticket"] = new_t
                                    st.toast(f"Checked in {r['vehicle_number']}! FASTag `{tag_to_link}` linked & {CURRENCY_SYMBOL}{r.get('deposit_amount', 0.0):.2f} credited.", icon="✅")
                                    st.rerun()
                                except Exception as ex:
                                    st.error(f"Failed to check-in: {ex}")
                        with c_btn2:
                            if st.button("❌ Cancel (Non-Refundable)", key=f"res_cancel_{r['reservation_id']}", use_container_width=True):
                                cancel_reservation(r["reservation_id"])
                                st.toast("Reservation cancelled. Bay restored to Available. Deposit retained.", icon="⚠️")
                                st.rerun()

        render_realtime_reservations(res_filter)

# ==============================================================================
# TAB 6: ANALYTICS & CONFIGURATION
# ==============================================================================
with tab_analytics:
    st.subheader("📊 Analytics, Audit Logs & Rate Settings")
    
    a_col1, a_col2 = st.columns(2)
    
    all_slots = get_slots()
    all_tickets = get_all_tickets(limit=200)

    with a_col1:
        st.markdown("##### 🚗 Bay Status Breakdown")
        status_counts = pd.DataFrame(all_slots)["status"].value_counts().reset_index()
        status_counts.columns = ["Status", "Count"]
        st.bar_chart(status_counts.set_index("Status"), color="#3b82f6")

    with a_col2:
        st.markdown("##### 🚙 Vehicle Types Parked Today")
        if all_tickets:
            v_types_df = pd.DataFrame(all_tickets)["vehicle_type"].value_counts().reset_index()
            v_types_df.columns = ["Type", "Count"]
            st.bar_chart(v_types_df.set_index("Type"), color="#10b981")
        else:
            st.info("No vehicle data recorded yet.")

    st.write("---")
    st.markdown("##### 📜 Transaction History & Financial Audit Trails")
    
    tab_aud1, tab_aud2 = st.tabs(["🎫 Parking Exit Tickets", "📅 Advance Bookings & No-Show Ledger"])
    with tab_aud1:
        if all_tickets:
            tickets_df = pd.DataFrame(all_tickets)
            display_cols = [
                "ticket_id", "vehicle_number", "vehicle_type", "slot_number",
                "entry_time", "exit_time", "duration_minutes", "total_fee",
                "prepaid_deposit", "payment_status", "payment_method"
            ]
            available_cols = [c for c in display_cols if c in tickets_df.columns]
            st.dataframe(tickets_df[available_cols], use_container_width=True, hide_index=True)

            csv_data = tickets_df.to_csv(index=False).encode('utf-8')
            st.download_button(
                "📥 Export Tickets to CSV",
                data=csv_data,
                file_name=f"parking_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                mime="text/csv"
            )
        else:
            st.info("No transaction records available.")

    with tab_aud2:
        all_res = get_reservations()
        if all_res:
            res_df = pd.DataFrame(all_res)
            res_cols = [
                "reservation_id", "customer_name", "vehicle_number", "vehicle_type",
                "slot_number", "reserved_for", "status", "deposit_amount", "payment_method", "forfeited_at"
            ]
            avail_res_cols = [c for c in res_cols if c in res_df.columns]
            st.dataframe(res_df[avail_res_cols], use_container_width=True, hide_index=True)
            res_csv = res_df.to_csv(index=False).encode('utf-8')
            st.download_button(
                "📥 Export Reservations to CSV",
                data=res_csv,
                file_name=f"reservations_ledger_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                mime="text/csv"
            )
        else:
            st.info("No advance reservation records available.")

    st.write("---")
    st.markdown("##### ⚙️ Hourly Pricing & Tariff Configuration")
    st.info("ℹ️ **Active Standard Policy (Model B)**: The 1st hour is charged at the vehicle's full base tariff. Any parking duration beyond the 1st hour is billed in 30-minute prorated slabs (at 50% of the hourly rate) + 18% GST. FASTag NETC auto-debit applies this standard automatically.")
    rates = get_rates()
    
    r_cols = st.columns(len(rates))
    for idx, (v_name, r_info) in enumerate(rates.items()):
        with r_cols[idx]:
            with st.container():
                st.markdown(f"**{v_name}**")
                new_hourly = st.number_input(
                    f"Hourly ({CURRENCY_SYMBOL})",
                    min_value=5.0,
                    max_value=500.0,
                    value=float(r_info["hourly_rate"]),
                    step=5.0,
                    key=f"rate_{v_name}"
                )
                new_min = st.number_input(
                    f"Base Fee ({CURRENCY_SYMBOL})",
                    min_value=5.0,
                    max_value=500.0,
                    value=float(r_info["min_charge"]),
                    step=5.0,
                    key=f"min_{v_name}"
                )
                if st.button(f"Save {v_name}", key=f"save_rate_{v_name}", use_container_width=True):
                    update_rate(v_name, new_hourly, new_min)
                    st.toast(f"Updated rate for {v_name}!")
                    st.rerun()

    st.write("---")
    st.markdown("##### 🧹 Production Facility Maintenance")
    p_col1, p_col2 = st.columns([2, 1])
    with p_col1:
        st.write("Reset facility to a **100% Clean Production State**: releases all occupied bays to **Available** and purges all mock/test tickets.")
    with p_col2:
        if st.button("🧼 Reset to Clean Production", type="secondary", use_container_width=True):
            reset_to_clean_production()
            st.session_state.clear()
            st.toast("✅ Facility reset to 100% clean production state!")
            st.rerun()

# ==============================================================================
# TAB 7: MOBILE APPLICATION (ANDROID & IOS) & REST API
# ==============================================================================
with tab_mobile:
    st.subheader("📱 Cross-Platform Mobile Application (Android & iOS)")
    st.caption("Native Flutter cross-platform mobile client powered by the ParkFlow FastAPI REST API.")

    # Status Cards
    m_s1, m_s2, m_s3 = st.columns(3)
    with m_s1:
        render_html("""
        <div style="background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 12px; padding: 14px;">
            <div style="font-size: 0.75rem; font-weight: 800; color: #065f46;">FASTAPI REST BACKEND</div>
            <div style="font-size: 1.3rem; font-weight: 900; color: #047857; margin: 4px 0;">🔒 ONLINE HTTPS (Port 8000)</div>
            <div style="font-size: 0.8rem; color: #065f46;">Interactive docs: <code>https://localhost:8000/docs</code></div>
        </div>
        """)
    with m_s2:
        render_html("""
        <div style="background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 12px; padding: 14px;">
            <div style="font-size: 0.75rem; font-weight: 800; color: #1e40af;">MOBILE ENGINE</div>
            <div style="font-size: 1.3rem; font-weight: 900; color: #1d4ed8; margin: 4px 0;">Flutter (Dart)</div>
            <div style="font-size: 0.8rem; color: #1e40af;">Single codebase for Android (.apk) & iOS (.ipa)</div>
        </div>
        """)
    with m_s3:
        render_html("""
        <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 14px;">
            <div style="font-size: 0.75rem; font-weight: 800; color: #475569;">APP ARCHITECTURE</div>
            <div style="font-size: 1.3rem; font-weight: 900; color: #0f172a; margin: 4px 0;">MVVM + Provider</div>
            <div style="font-size: 0.8rem; color: #475569;">Layered Separation (UI, ViewModel, Repository, Service)</div>
        </div>
        """)

    st.write("")

    sub_t1, sub_t2, sub_t3 = st.tabs(["📱 Interactive Mobile Preview", "📡 Live REST API Explorer", "🛠️ Build & Run Commands"])

    with sub_t1:
        st.markdown("##### 📱 Live Mobile Application Frame Preview")
        st.caption("This realistic phone frame illustrates how the Flutter mobile application renders on both iOS and Android devices:")

        c_sim1, c_sim2 = st.columns([1.2, 1])

        with c_sim1:
            metrics_now = get_dashboard_metrics()
            all_bays_now = get_slots()
            occupied_now = [b for b in all_bays_now if b["status"] == "Occupied"]

            render_html(f"""
            <div style="max-width: 380px; margin: 0 auto; background: #0f172a; border-radius: 40px; padding: 14px; box-shadow: 0 20px 40px rgba(0,0,0,0.3); border: 4px solid #334155;">
                <!-- Phone Speaker / Dynamic Island -->
                <div style="width: 110px; height: 18px; background: #000; border-radius: 20px; margin: 0 auto 10px auto;"></div>
                
                <!-- Phone Screen -->
                <div style="background: #f8fafc; border-radius: 28px; overflow: hidden; height: 560px; display: flex; flex-direction: column; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
                    
                    <!-- Mobile App Bar -->
                    <div style="background: #1e3a8a; padding: 16px 14px; color: white; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <div style="font-size: 0.7rem; font-weight: 700; color: #93c5fd; letter-spacing: 0.05em;">SMART PARKING</div>
                            <div style="font-size: 1.1rem; font-weight: 900;">🅿️ ParkFlow Mobile</div>
                        </div>
                        <div style="background: #10b981; color: white; padding: 3px 8px; border-radius: 12px; font-size: 0.65rem; font-weight: 800;">
                            ● LIVE
                        </div>
                    </div>

                    <!-- Mobile Screen Content (Scrollable) -->
                    <div style="flex: 1; overflow-y: auto; padding: 12px;">
                        
                        <!-- Top Summary Card -->
                        <div style="background: linear-gradient(135deg, #1e3a8a, #2563eb); border-radius: 12px; padding: 12px; color: white; margin-bottom: 10px;">
                            <div style="font-size: 0.65rem; color: #bfdbfe; font-weight: bold;">LIVE BAY AVAILABILITY</div>
                            <div style="display: flex; justify-content: space-between; margin-top: 6px;">
                                <div>
                                    <div style="font-size: 1.3rem; font-weight: 900; color: #6ee7b7;">{metrics_now['available_count']}</div>
                                    <div style="font-size: 0.65rem; color: #e2e8f0;">Available</div>
                                </div>
                                <div>
                                    <div style="font-size: 1.3rem; font-weight: 900; color: #fca5a5;">{metrics_now['occupied_count']}</div>
                                    <div style="font-size: 0.65rem; color: #e2e8f0;">Occupied</div>
                                </div>
                                <div>
                                    <div style="font-size: 1.3rem; font-weight: 900; color: #fde68a;">{metrics_now['reserved_count']}</div>
                                    <div style="font-size: 0.65rem; color: #e2e8f0;">Reserved</div>
                                </div>
                                <div>
                                    <div style="font-size: 1.3rem; font-weight: 900; color: white;">{metrics_now['occupancy_pct']}%</div>
                                    <div style="font-size: 0.65rem; color: #e2e8f0;">Occupancy</div>
                                </div>
                            </div>
                        </div>

                        <!-- Action Shortcuts -->
                        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; margin-bottom: 12px;">
                            <div style="background: white; border: 1px solid #e2e8f0; border-radius: 10px; padding: 10px; text-align: center;">
                                <div style="font-size: 1.2rem;">📅</div>
                                <div style="font-size: 0.75rem; font-weight: bold; color: #0f172a; margin-top: 2px;">Advance Book</div>
                                <div style="font-size: 0.65rem; color: #64748b;">1-Hr ₹59 Deposit</div>
                            </div>
                            <div style="background: white; border: 1px solid #e2e8f0; border-radius: 10px; padding: 10px; text-align: center;">
                                <div style="font-size: 1.2rem;">📡</div>
                                <div style="font-size: 0.75rem; font-weight: bold; color: #0f172a; margin-top: 2px;">FASTag Exit</div>
                                <div style="font-size: 0.65rem; color: #64748b;">Zero-Debit Settle</div>
                            </div>
                        </div>

                        <!-- Mini Bay Grid Preview -->
                        <div style="font-size: 0.75rem; font-weight: 800; color: #334155; margin-bottom: 6px;">FACILITY BAYS OVERVIEW</div>
                        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px;">
                            {''.join([
                                f'''<div style="background: white; border: 1px solid {'#10b981' if b['status']=='Available' else ('#ef4444' if b['status']=='Occupied' else '#f59e0b')}; border-radius: 8px; padding: 6px; text-align: center;">
                                    <div style="font-weight: 900; font-size: 0.75rem; color: #0f172a;">{b['slot_number']}</div>
                                    <div style="font-size: 0.6rem; color: #64748b;">{b['slot_type']}</div>
                                    <div style="font-size: 0.55rem; font-weight: bold; color: {'#10b981' if b['status']=='Available' else ('#ef4444' if b['status']=='Occupied' else '#f59e0b')};">{b['status']}</div>
                                </div>'''
                                for b in all_bays_now[:6]
                            ])}
                        </div>
                    </div>

                    <!-- Bottom Navigation Bar -->
                    <div style="background: white; border-top: 1px solid #e2e8f0; padding: 8px 12px; display: flex; justify-content: space-around; align-items: center;">
                        <div style="text-align: center; color: #2563eb;">
                            <div style="font-size: 1.1rem;">🚗</div>
                            <div style="font-size: 0.6rem; font-weight: bold;">Bays</div>
                        </div>
                        <div style="text-align: center; color: #64748b;">
                            <div style="font-size: 1.1rem;">📅</div>
                            <div style="font-size: 0.6rem;">Reserve</div>
                        </div>
                        <div style="text-align: center; color: #64748b;">
                            <div style="font-size: 1.1rem;">🎟️</div>
                            <div style="font-size: 0.6rem;">Pass</div>
                        </div>
                        <div style="text-align: center; color: #64748b;">
                            <div style="font-size: 1.1rem;">💳</div>
                            <div style="font-size: 0.6rem;">Exit</div>
                        </div>
                        <div style="text-align: center; color: #64748b;">
                            <div style="font-size: 1.1rem;">🔍</div>
                            <div style="font-size: 0.6rem;">Locate</div>
                        </div>
                    </div>
                </div>
            </div>
            """)

        with c_sim2:
            st.markdown("##### 📲 Instant Mobile Test (Scan with Phone)")
            st.image("mobile_qr.png", caption="Scan with your Android phone camera to open on mobile", width=200)
            
            st.markdown("""
            **How to test on your phone right now:**
            1. Connect your mobile phone to the same Wi-Fi network.
            2. Point your camera at the QR code above or open in Chrome:
            """)
            st.code("https://10.9.240.129:8501", language="text")
            st.caption("*(Note: Tap 'Advanced' -> 'Proceed to 10.9.240.129 (unsafe)' once in your mobile browser to accept the local SSL certificate).*")
            st.markdown("""
            3. Tap Chrome's menu (`⋮`) and select **"Add to Home screen"** / **"Install App"**.
            4. The app will install as a standalone mobile app on your Android home screen with zero setup!
            
            ---
            
            ##### 📦 Download Compiled Android APK:
            The native Flutter APK has been built via GitHub Actions and is ready for download:
            """)
            st.image("apk_qr.png", caption="Scan with mobile camera to download APK directly", width=180)
            
            c_apk1, c_apk2 = st.columns(2)
            with c_apk1:
                st.link_button("📥 Release APK (v1.0.9)", "https://github.com/Kishore20111992/carpark-app/releases/download/v1.0.9/app-release.apk", type="primary", use_container_width=True)
            with c_apk2:
                st.link_button("📥 Debug APK (v1.0.9)", "https://github.com/Kishore20111992/carpark-app/releases/download/v1.0.9/app-debug.apk", type="secondary", use_container_width=True)
            
            st.markdown("""
            - **Direct GitHub Release**: [View Release v1.0.9 on GitHub](https://github.com/Kishore20111992/carpark-app/releases/tag/v1.0.9)
            - **Installation Note**: Tap the downloaded file in your notification bar and tap **Install** (enable "Install unknown apps" if prompted).
            """)

    with sub_t2:
        st.markdown("##### 📡 Live REST API Endpoints (HTTPS Secured)")
        st.write("All endpoints are live and operational on `https://localhost:8000` (or `https://10.9.240.129:8000`). Open the interactive Swagger UI below:")

        st.link_button("🚀 Open Interactive Swagger / OpenAPI Docs", "https://localhost:8000/docs", type="primary")

        st.markdown("###### Core API Route Reference:")
        api_table = pd.DataFrame([
            {"Method": "GET", "Endpoint": "/api/health", "Description": "Backend health check and timestamp"},
            {"Method": "GET", "Endpoint": "/api/bays/summary", "Description": "Live capacity, available/occupied count, occupancy %, revenue"},
            {"Method": "GET", "Endpoint": "/api/bays", "Description": "List all 24 bays with category, zone, status, active tickets"},
            {"Method": "POST", "Endpoint": "/api/checkin", "Description": "Vehicle check-in; auto-fulfills advance booking and links FASTag"},
            {"Method": "POST", "Endpoint": "/api/checkout", "Description": "Calculates bill (Model B 30m slabs) & executes FASTag debit"},
            {"Method": "POST", "Endpoint": "/api/reservations", "Description": "Creates advance booking with 1-hr deposit (Rejects Cash & FASTag)"},
            {"Method": "GET", "Endpoint": "/api/reservations", "Description": "List active, checked-in, and no-show forfeited reservations"},
            {"Method": "GET", "Endpoint": "/api/locator", "Description": "Finds parked vehicle location and walking directions"},
            {"Method": "GET", "Endpoint": "/api/rates", "Description": "Returns hourly tariff rates by vehicle category"}
        ])
        st.dataframe(api_table, use_container_width=True, hide_index=True)

    with sub_t3:
        st.markdown("##### 🛠️ How to Build and Run the Flutter Mobile App")
        
        st.markdown("###### 1. Prerequisites")
        st.code("flutter doctor", language="bash")

        st.markdown("###### 2. Run on Android Emulator or Device")
        st.code("""cd mobile_app
flutter pub get
flutter run -d android""", language="bash")

        st.markdown("###### 3. Build Production Android Release APK")
        st.code("""cd mobile_app
flutter build apk --release
# Output: mobile_app/build/app/outputs/flutter-apk/app-release.apk""", language="bash")

        st.markdown("###### 4. Run on iOS Simulator or Device (macOS)")
        st.code("""cd mobile_app
flutter pub get
cd ios && pod install && cd ..
flutter run -d ios""", language="bash")

        st.markdown("###### 5. Build Production iOS IPA")
        st.code("""cd mobile_app
flutter build ipa --release""", language="bash")

# --- FOOTER ---

render_html("""
<div style="text-align: center; color: #94a3b8; font-size: 0.8rem; margin-top: 40px; padding-top: 15px; border-top: 1px solid #e2e8f0;">
    ParkFlow Municipal Smart Parking System &copy; 2026 | Built with Python & Streamlit
</div>
""")