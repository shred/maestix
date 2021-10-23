/*
 * Maestix Library
 *
 * Copyright (C) 2021 Richard "Shred" Koerber
 *	http://maestix.shredzone.org
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#pragma libcall MaestixBase AllocMaestro 1E 801
#pragma libcall MaestixBase FreeMaestro 24 801
#pragma libcall MaestixBase SetMaestro 2A 9802
#pragma libcall MaestixBase GetStatus 30 0802
#pragma libcall MaestixBase TransmitData 36 9802
#pragma libcall MaestixBase ReceiveData 3C 9802
#pragma libcall MaestixBase FlushTransmit 42 801
#pragma libcall MaestixBase FlushReceive 48 801
#pragma libcall MaestixBase StartRealtime 4E 9802
#pragma libcall MaestixBase StopRealtime 54 801
#pragma libcall MaestixBase UpdateRealtime 5A 9802
#pragma libcall MaestixBase ReadPostLevel 66 801
#pragma tagcall MaestixBase AllocMaestroTags 1E 801
#pragma tagcall MaestixBase SetMaestroTags 2A 9802
#pragma tagcall MaestixBase StartRealtimeTags 4E 9802
#pragma tagcall MaestixBase UpdateRealtimeTags 5A 9802
#pragma tagcall MaestixBase ReadPostLevelTags 66 9802
