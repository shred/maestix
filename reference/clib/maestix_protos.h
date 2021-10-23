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

struct MaestroBase* AllocMaestro(struct TagItem*);
struct MaestroBase* AllocMaestroTags(ULONG,...);
void FlushReceive(struct MaestroBase *);
void FlushTransmit(struct MaestroBase *);
void FreeMaestro(struct MaestroBase *);
ULONG GetStatus(struct MaestroBase *,ULONG);
ULONG ReadPostLevel(struct MaestroBase *,struct TagItem *);
ULONG ReadPostLevelTags(struct MaestroBase *,ULONG,...);
void ReceiveData(struct MaestroBase *,struct DataMessage *);
void SetMaestro(struct MaestroBase *,struct TagItem *);
void SetMaestroTags(struct MaestroBase *,ULONG,...);
void StartRealtime(struct MaestroBase *,struct TagItem *);
void StartRealtimeTags(struct MaestroBase *,ULONG,...);
void StopRealtime(struct MaestroBase *);
void TransmitData(struct MaestroBase *,struct DataMessage *);
void UpdateRealtime(struct MaestroBase *,struct TagItem *);
void UpdateRealtimeTags(struct MaestroBase *,ULONG,...);
