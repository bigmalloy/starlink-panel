#![recursion_limit = "256"]
//! starlink-dish — thin gRPC client for the Starlink dish API.
//!
//! Designed as a drop-in replacement for grpcurl in luci-app-starlink-panel.
//! Outputs JSON on stdout; errors write {"available":false,"error":"..."}.
//!
//! Usage:
//!   starlink-dish [addr] dish     — full dish telemetry JSON
//!   starlink-dish [addr] reboot   — reboot the dish, outputs {"success":true|false}

use clap::Parser;
use serde_json::{json, Value};
use starlink_grpc_client::client::DishClient;
use starlink_grpc_client::space_x::api::device::{
    self as device,
    device_client::DeviceClient,
    request::Request as OneofRequest,
    Request as DeviceRequest,
    RebootRequest,
};

#[derive(Parser)]
#[command(name = "starlink-dish", about = "Starlink dish gRPC CLI")]
struct Args {
    /// gRPC address (default: http://192.168.100.1:9200)
    #[arg(default_value = "http://192.168.100.1:9200")]
    addr: String,

    /// Command: dish | reboot
    command: String,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    let output = match args.command.as_str() {
        "dish" => match dish_status(&args.addr).await {
            Ok(v) => v,
            Err(e) => json!({"available": false, "error": e.to_string()}),
        },
        "reboot" => match reboot_dish(&args.addr).await {
            Ok(v) => v,
            Err(e) => json!({"success": false, "error": e.to_string()}),
        },
        other => {
            eprintln!("Unknown command: {}. Use 'dish' or 'reboot'.", other);
            std::process::exit(1);
        }
    };

    println!("{}", output);
}

// ── helpers ───────────────────────────────────────────────────────────────────

fn disablement_name(code: i32) -> &'static str {
    match code {
        0 => "OKAY",
        1 => "UNKNOWN_REASON",
        2 => "AWAITING_PAYMENT",
        3 => "HARDWARE_NOT_ACTIVATED",
        4 => "HARDWARE_CHANGE_SUSPENDED",
        5 => "ACCOUNT_DISABLED",
        _ => "OKAY",   // treat unknown as okay rather than false-alerting
    }
}

// ── dish status ───────────────────────────────────────────────────────────────

async fn dish_status(addr: &str) -> Result<Value, Box<dyn std::error::Error>> {
    let mut client = DishClient::connect(addr).await?;
    let status = client.get_status().await?;

    use device::response::Response as OneofResponse;

    let dish = match status.raw.response.as_ref() {
        Some(OneofResponse::DishGetStatus(d)) => d,
        _ => return Err("response did not contain DishGetStatus".into()),
    };

    let info   = dish.device_info.as_ref();
    let dstate = dish.device_state.as_ref();
    let alerts = dish.alerts.as_ref();
    let obst   = dish.obstruction_stats.as_ref();
    let align  = dish.alignment_stats.as_ref();
    let ready  = dish.ready_states.as_ref();
    let init   = dish.initialization_duration_seconds.as_ref();
    let gps    = dish.gps_stats.as_ref();

    let rf = ready.map(|r| r.rf).unwrap_or(false);

    // Gen3 dishes report disablement_code=1 (UNKNOWN_REASON) even when fully
    // connected.  Treat code 1 as OKAY when RF is ready — it is not a real
    // disablement, just a firmware quirk on this hardware generation.
    let effective_code = if dish.disablement_code == 1 && rf { 0 } else { dish.disablement_code };
    let dis_str = disablement_name(effective_code);

    // Infer state from effective disablement + RF ready
    // (Gen3 omits state field on the wire when CONNECTED).
    let state_str: String = if effective_code == 0 && rf {
        "CONNECTED".to_string()
    } else if effective_code != 0 {
        format!("DISABLED ({})", dis_str)
    } else {
        "UNKNOWN".to_string()
    };

    let outages: Value = dish.outage.iter().map(|o| {
        json!({
            "cause":            o.cause().as_str_name(),
            "startTimestampNs": o.start_timestamp_ns,
            "duration":         o.duration_ns as f64 / 1_000_000_000.0,
        })
    }).collect();

    Ok(json!({
        "available":               true,
        "state":                   state_str,
        "uptime":                  dstate.map(|s| s.uptime_s).unwrap_or(0),
        "hardware":                info.map(|d| d.hardware_version.as_str()).unwrap_or(""),
        "software":                info.map(|d| d.software_version.as_str()).unwrap_or(""),
        "latency_ms":              dish.pop_ping_latency_ms,
        "drop_rate":               dish.pop_ping_drop_rate,
        "fraction_obstructed":     obst.map(|o| o.fraction_obstructed).unwrap_or(0.0),
        "downlink_bps":            dish.downlink_throughput_bps,
        "uplink_bps":              dish.uplink_throughput_bps,
        "snr_above_noise":         dish.is_snr_above_noise_floor.to_string(),
        "eth_speed_mbps":          dish.eth_speed_mbps,
        "gps_sats":                gps.map(|g| g.gps_sats).unwrap_or(0),
        "elevation_deg":           dish.boresight_elevation_deg,
        "attitude":                align.map(|a| a.attitude_estimation_state().as_str_name()).unwrap_or(""),
        "tilt_angle_deg":          align.map(|a| a.tilt_angle_deg).unwrap_or(0.0),
        "bore_elevation_deg":      align.map(|a| a.boresight_elevation_deg).unwrap_or(0.0),
        "desired_elevation_deg":   align.map(|a| a.desired_boresight_elevation_deg).unwrap_or(0.0),
        "bore_azimuth_deg":        align.map(|a| a.boresight_azimuth_deg).unwrap_or(0.0),
        "desired_azimuth_deg":     align.map(|a| a.desired_boresight_azimuth_deg).unwrap_or(0.0),
        "gps_valid":               gps.map(|g| g.gps_valid).unwrap_or(false).to_string(),
        "snr_persistently_low":    dish.is_snr_persistently_low.to_string(),
        "sw_reboot_ready":         dish.swupdate_reboot_ready.to_string(),
        "class_of_service":        dish.class_of_service().as_str_name(),
        "mobility_class":          dish.mobility_class().as_str_name(),
        "seconds_to_slot":         dish.seconds_to_first_nonempty_slot,
        "avg_obstruction_dur":     obst.map(|o| o.avg_prolonged_obstruction_duration_s).unwrap_or(0.0),
        "avg_obstruction_int":     obst.map(|o| o.avg_prolonged_obstruction_interval_s).unwrap_or(0.0),
        "sw_update_state":         dish.software_update_state().as_str_name(),
        "currently_obstructed":    obst.map(|o| o.currently_obstructed).unwrap_or(false).to_string(),
        "al_heating":              alerts.map(|a| a.is_heating).unwrap_or(false).to_string(),
        "al_throttle":             alerts.map(|a| a.thermal_throttle).unwrap_or(false).to_string(),
        "al_shutdown":             alerts.map(|a| a.thermal_shutdown).unwrap_or(false).to_string(),
        "al_psu_throttle":         alerts.map(|a| a.power_supply_thermal_throttle).unwrap_or(false).to_string(),
        "al_motors":               alerts.map(|a| a.motors_stuck).unwrap_or(false).to_string(),
        "al_mast":                 alerts.map(|a| a.mast_not_near_vertical).unwrap_or(false).to_string(),
        "al_slow_eth":             alerts.map(|a| a.slow_ethernet_speeds).unwrap_or(false).to_string(),
        "al_roaming":              alerts.map(|a| a.roaming).unwrap_or(false).to_string(),
        "al_unexpected_location":  alerts.map(|a| a.unexpected_location).unwrap_or(false).to_string(),
        "al_install_pending":      alerts.map(|a| a.install_pending).unwrap_or(false).to_string(),
        "disablement":             dis_str,
        "dish_id":                 info.map(|d| d.id.as_str()).unwrap_or(""),
        "country_code":            info.map(|d| d.country_code.as_str()).unwrap_or(""),
        "bootcount":               info.map(|d| d.bootcount).unwrap_or(0),
        "has_signed_cals":         dish.has_signed_cals.to_string(),
        "rs_rf":                   ready.map(|r| r.rf).unwrap_or(false).to_string(),
        "rs_cady":                 ready.map(|r| r.cady).unwrap_or(false).to_string(),
        "rs_scp":                  ready.map(|r| r.scp).unwrap_or(false).to_string(),
        "rs_l1l2":                 ready.map(|r| r.l1l2).unwrap_or(false).to_string(),
        "rs_xphy":                 ready.map(|r| r.xphy).unwrap_or(false).to_string(),
        "rs_aap":                  ready.map(|r| r.aap).unwrap_or(false).to_string(),
        "attitude_uncertainty_deg":align.map(|a| a.attitude_uncertainty_deg).unwrap_or(0.0),
        "dl_restrict":             dish.dl_bandwidth_restricted_reason().as_str_name(),
        "ul_restrict":             dish.ul_bandwidth_restricted_reason().as_str_name(),
        "swupdate_reboot_hour":    dish.config.as_ref().map(|c| c.swupdate_reboot_hour).unwrap_or(3),
        "obst_patches_valid":      obst.map(|o| o.patches_valid).unwrap_or(0),
        "init_stable_s":           init.map(|i| i.stable_connection).unwrap_or(0),
        "init_first_ping_s":       init.map(|i| i.first_pop_ping).unwrap_or(0),
        "init_gps_s":              init.map(|i| i.gps_valid).unwrap_or(0),
        "outages":                 outages,
    }))
}

// ── reboot ────────────────────────────────────────────────────────────────────

async fn reboot_dish(addr: &str) -> Result<Value, Box<dyn std::error::Error>> {
    // DeviceClient is generated against the same tonic version as the crate uses.
    // We share the same tonic dep so Channel is compatible.
    let channel = tonic::transport::Channel::from_shared(addr.to_string())?
        .connect()
        .await?;

    let mut client = DeviceClient::new(channel);

    let req = DeviceRequest {
        id: 0,
        epoch_id: 0,
        target_id: String::new(),
        request: Some(OneofRequest::Reboot(RebootRequest {})),
    };

    let resp = client.handle(tonic::Request::new(req)).await?;

    use device::response::Response as OneofResponse;
    let ok = matches!(resp.into_inner().response, Some(OneofResponse::Reboot(_)));

    Ok(json!({ "success": ok }))
}
