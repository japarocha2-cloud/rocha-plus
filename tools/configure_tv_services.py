"""Configure public service URLs; never accepts merchant private credentials."""
import argparse
import json
from pathlib import Path
from validate_billing_config import valid_endpoint
ROOT = Path(__file__).resolve().parents[1]
def configure(pairing, billing, intro, root=ROOT):
    for value in (pairing, billing, intro):
        if not valid_endpoint(value): raise ValueError('Use confirmed deployed HTTPS URLs')
    (root/'platforms/roku/config/auth.json').write_text(json.dumps({
        'enabled':True,'endpoint':pairing,'billingEndpoint':billing,'introUrl':intro},indent=2)+'\n')
    (root/'platforms/web-tv/config.json').write_text(json.dumps({
        'pairingEndpoint':pairing,'billingEndpoint':billing},indent=2)+'\n')
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--pairing',required=True)
    parser.add_argument('--billing',required=True)
    parser.add_argument('--intro',required=True)
    args=parser.parse_args();configure(args.pairing,args.billing,args.intro)
