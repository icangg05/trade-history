<?php

namespace App\Models\Concerns;

use App\Support\Hashid;

/**
 * Model yang id-nya tidak pernah tampil apa adanya. `getRouteKey()` inilah yang
 * dipakai helper `route()`, dan controller memakainya juga saat menyusun props
 * supaya yang sampai ke browser cuma satu bentuk id.
 */
trait HasHashid
{
    public function getRouteKey(): string
    {
        return Hashid::encode($this->getKey());
    }
}
